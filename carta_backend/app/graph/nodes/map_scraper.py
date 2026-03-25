"""Node 3: map_scraper — Fetches nearby places using Overpass API (free, no key).

Replaces the ReAct agent approach with direct Overpass queries for reliability.
Runs in parallel with event_search (Node 2).
Returns empty list on failure — never prevents the planner from running.
"""

from __future__ import annotations

import math

import httpx

from app.config import get_settings
from app.graph.state import GraphState, PlaceResult, get_city_coords
from app.utils.logger import get_logger

logger = get_logger(__name__)

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
SERPER_URL = "https://google.serper.dev/search"


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Return the Haversine distance in km between two lat/lng pairs."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlng / 2) ** 2
    )
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


async def _query_overpass(client: httpx.AsyncClient, query: str) -> list[dict]:
    """Execute an Overpass API query and return parsed results."""
    try:
        resp = await client.post(
            OVERPASS_URL,
            data={"data": query},
            timeout=15.0,
        )
        resp.raise_for_status()
        data = resp.json()

        results = []
        for element in data.get("elements", []):
            tags = element.get("tags", {})
            name = tags.get("name", "")
            if not name:
                continue

            address_parts = [
                tags.get("addr:housenumber", ""),
                tags.get("addr:street", ""),
                tags.get("addr:city", ""),
            ]
            address = " ".join(p for p in address_parts if p).strip()
            if not address:
                address = tags.get("addr:full", "")

            results.append({
                "name": name,
                "address": address,
                "lat": float(element.get("lat", 0)),
                "lng": float(element.get("lon", 0)),
            })

        return results
    except Exception as exc:
        logger.error("Overpass query failed: %s", str(exc)[:200])
        return []


async def _fetch_restaurants(client: httpx.AsyncClient, lat: float, lng: float) -> list[PlaceResult]:
    """Fetch restaurants/cafes/bars near the given coordinates."""
    query = f"""
[out:json][timeout:10];
node["amenity"~"restaurant|cafe|bar"](around:1500,{lat},{lng});
out body 5;
"""
    results = await _query_overpass(client, query)
    return [
        PlaceResult(
            name=r["name"],
            place_type="restaurant",
            address=r["address"],
            lat=r["lat"],
            lng=r["lng"],
            source="overpass",
        )
        for r in results
    ]


async def _fetch_attractions(client: httpx.AsyncClient, lat: float, lng: float) -> list[PlaceResult]:
    """Fetch attractions/museums/viewpoints near the given coordinates."""
    query = f"""
[out:json][timeout:10];
node["tourism"~"attraction|museum|viewpoint"](around:2000,{lat},{lng});
out body 3;
"""
    results = await _query_overpass(client, query)
    return [
        PlaceResult(
            name=r["name"],
            place_type="attraction",
            address=r["address"],
            lat=r["lat"],
            lng=r["lng"],
            source="overpass",
        )
        for r in results
    ]


async def _fetch_fuel_stops(client: httpx.AsyncClient, lat: float, lng: float) -> list[PlaceResult]:
    """Fetch fuel stations near the midpoint between home and event."""
    query = f"""
[out:json][timeout:10];
node["amenity"="fuel"](around:2000,{lat},{lng});
out body 3;
"""
    results = await _query_overpass(client, query)
    return [
        PlaceResult(
            name=r["name"],
            place_type="fuel",
            address=r["address"],
            lat=r["lat"],
            lng=r["lng"],
            source="overpass",
        )
        for r in results
    ]


async def _search_serper(api_key: str, venue_name: str, city: str) -> list[PlaceResult]:
    """Search for context enrichment using Serper web search."""
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                SERPER_URL,
                json={
                    "q": f"top things to do near {venue_name} {city}",
                    "gl": "in",
                    "hl": "en",
                    "num": 3,
                },
                headers={
                    "X-API-KEY": api_key,
                    "Content-Type": "application/json",
                },
            )
            resp.raise_for_status()
            data = resp.json()

        results = []
        for item in data.get("organic", [])[:3]:
            results.append(
                PlaceResult(
                    name=item.get("title", "Unknown"),
                    place_type="attraction",
                    address=item.get("snippet", ""),
                    lat=0.0,
                    lng=0.0,
                    source="serper",
                )
            )
        logger.info("Serper returned %d results", len(results))
        return results
    except Exception as exc:
        logger.error("Serper search failed: %s", str(exc)[:200])
        return []


async def map_scraper(state: GraphState) -> dict:
    """Fetch nearby places using Overpass API (free, no key needed).

    Runs in parallel with event_search (Node 2).
    Queries for restaurants, attractions, and optionally fuel stops.
    Each query catches its own exceptions — partial results are fine.
    """
    settings = get_settings()
    profile = state.get("user_profile") or {}
    intent = state.get("parsed_intent")

    # Get city coordinates
    city = "Chennai"
    if intent and intent.detected_city:
        city = intent.detected_city
    elif profile.get("city"):
        city = profile["city"]

    default_lat, default_lng = get_city_coords(city)
    home_lat = float(profile.get("home_lat") or default_lat)
    home_lng = float(profile.get("home_lng") or default_lng)

    # Use city centre for place searches
    search_lat = home_lat
    search_lng = home_lng

    places: list[PlaceResult] = []

    try:
        async with httpx.AsyncClient() as client:
            # Fetch restaurants and attractions concurrently
            import asyncio
            restaurant_task = _fetch_restaurants(client, search_lat, search_lng)
            attraction_task = _fetch_attractions(client, search_lat, search_lng)

            results = await asyncio.gather(restaurant_task, attraction_task, return_exceptions=True)

            for result in results:
                if isinstance(result, list):
                    places.extend(result)
                elif isinstance(result, Exception):
                    logger.error("Overpass sub-query failed: %s", result)

            # Optionally fetch fuel stops if events are far from home
            events = state.get("events", [])
            if events:
                event_lat = events[0].lat
                event_lng = events[0].lng
                dist = _haversine_km(home_lat, home_lng, event_lat, event_lng)
                if dist > 10:
                    mid_lat = (home_lat + event_lat) / 2
                    mid_lng = (home_lng + event_lng) / 2
                    fuel_results = await _fetch_fuel_stops(client, mid_lat, mid_lng)
                    places.extend(fuel_results)

    except Exception as exc:
        logger.error("map_scraper error: %s", str(exc)[:200])

    # Optionally enrich with Serper web search
    if settings.serper_api_key:
        try:
            serper_results = await _search_serper(settings.serper_api_key, city, city)
            places.extend(serper_results)
        except Exception as exc:
            logger.error("Serper enrichment failed: %s", exc)

    logger.info("map_scraper returned %d places for %s", len(places), city)
    return {"places": places}
