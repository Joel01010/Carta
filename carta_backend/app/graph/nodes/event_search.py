"""Node 2: event_search — Fetches events from PredictHQ and Ticketmaster."""

from __future__ import annotations

import asyncio
from typing import Any

import httpx

from app.config import get_settings
from app.graph.state import GraphState, EventResult
from app.utils.logger import get_logger

logger = get_logger(__name__)

PREDICTHQ_BASE_URL = "https://api.predicthq.com/v1/events/"
TICKETMASTER_BASE_URL = "https://app.ticketmaster.com/discovery/v2/events.json"

# Map user-facing liked_event_types to PredictHQ category slugs
PREDICTHQ_CATEGORY_MAP: dict[str, str] = {
    "concerts": "concerts",
    "music": "concerts",
    "festivals": "festivals",
    "performing-arts": "performing-arts",
    "theatre": "performing-arts",
    "sports": "sports",
    "exhibitions": "expos",
    "conferences": "conferences",
}


# ---------------------------------------------------------------------------
# PredictHQ fetch
# ---------------------------------------------------------------------------

async def _fetch_predicthq(
    client: httpx.AsyncClient,
    settings,
    lat: float,
    lng: float,
    date_str: str,
    liked_types: list[str],
) -> list[dict[str, Any]]:
    """Fetch events from PredictHQ API."""
    categories = ",".join(
        PREDICTHQ_CATEGORY_MAP.get(t.lower(), t) for t in liked_types
    ) if liked_types else "concerts,festivals,performing-arts,sports"

    params: dict[str, Any] = {
        "within": f"15km@{lat},{lng}",
        "start.gte": date_str,
        "start.lte": date_str,
        "category": categories,
        "rank_level": "3,4,5",
        "limit": 8,
    }

    headers = {"Authorization": f"Bearer {settings.predicthq_api_key}"}

    response = await client.get(PREDICTHQ_BASE_URL, params=params, headers=headers)
    response.raise_for_status()
    data = response.json()

    results: list[dict[str, Any]] = []
    for ev in data.get("results", []):
        try:
            coords = ev.get("geo", {}).get("geometry", {}).get("coordinates", [None, None])
            lat_val = float(coords[1]) if coords[1] is not None else lat
            lng_val = float(coords[0]) if coords[0] is not None else lng

            entities = ev.get("entities", [])
            booking_url = entities[0].get("formatted_address", "") if entities else ""

            start_time = ev.get("start", "")

            results.append({
                "id": str(ev.get("id", "")),
                "name": ev.get("title", "Unknown Event"),
                "type": ev.get("category", "general"),
                "venue": ev.get("title", ""),
                "address": booking_url,
                "lat": lat_val,
                "lng": lng_val,
                "start_time": start_time,
                "price": 0,
                "booking_url": booking_url,
                "source": "predicthq",
            })
        except Exception as parse_err:
            logger.warning("PredictHQ: skipping unparseable event: %s", parse_err)

    logger.info("PredictHQ returned %d events", len(results))
    return results


# ---------------------------------------------------------------------------
# Ticketmaster fetch
# ---------------------------------------------------------------------------

async def _fetch_ticketmaster(
    client: httpx.AsyncClient,
    settings,
    lat: float,
    lng: float,
    date_str: str,
) -> list[dict[str, Any]]:
    """Fetch events from Ticketmaster Discovery API."""
    params: dict[str, Any] = {
        "apikey": settings.ticketmaster_api_key,
        "latlong": f"{lat},{lng}",
        "radius": 15,
        "unit": "km",
        "startDateTime": f"{date_str}T00:00:00Z",
        "endDateTime": f"{date_str}T23:59:59Z",
        "countryCode": "IN",
        "size": 5,
    }

    response = await client.get(TICKETMASTER_BASE_URL, params=params)
    response.raise_for_status()
    data = response.json()

    embedded = data.get("_embedded", {})
    raw_events = embedded.get("events", [])

    results: list[dict[str, Any]] = []
    for ev in raw_events:
        try:
            venues = ev.get("_embedded", {}).get("venues", [{}])
            venue = venues[0] if venues else {}
            location = venue.get("location", {})
            lat_val = float(location.get("latitude", lat))
            lng_val = float(location.get("longitude", lng))

            classifications = ev.get("classifications", [{}])
            segment = classifications[0].get("segment", {}) if classifications else {}
            ev_type = segment.get("name", "general")

            dates = ev.get("dates", {}).get("start", {})
            local_date = dates.get("localDate", date_str)
            local_time = dates.get("localTime", "00:00:00")
            start_time = f"{local_date}T{local_time}"

            price_ranges = ev.get("priceRanges", [])
            price = int(price_ranges[0].get("min", 0)) if price_ranges else 0

            results.append({
                "id": str(ev.get("id", "")),
                "name": ev.get("name", "Unknown Event"),
                "type": ev_type,
                "venue": venue.get("name", ""),
                "address": venue.get("address", {}).get("line1", ""),
                "lat": lat_val,
                "lng": lng_val,
                "start_time": start_time,
                "price": price,
                "booking_url": ev.get("url", ""),
                "source": "ticketmaster",
            })
        except Exception as parse_err:
            logger.warning("Ticketmaster: skipping unparseable event: %s", parse_err)

    logger.info("Ticketmaster returned %d events", len(results))
    return results


# ---------------------------------------------------------------------------
# Public node function
# ---------------------------------------------------------------------------

async def event_search(state: GraphState) -> dict:
    """Search PredictHQ and Ticketmaster concurrently for events matching intent.

    Runs in parallel with map_scraper (Node 3).
    - Both API calls are made concurrently via asyncio.gather().
    - If one source fails, results from the other are still returned.
    - Results are deduplicated by fuzzy name match (first 20 chars, lowercase).
    - Sorted ascending by price (lowest cost first).
    - Returns top 8 events that fit within the user's parsed_budget.
    """
    settings = get_settings()
    profile = state.get("user_profile") or {}
    intent = state.get("parsed_intent")

    if not intent:
        logger.warning("event_search called without parsed_intent; returning empty.")
        return {"events": []}

    liked_types: list[str] = profile.get("liked_event_types", [])
    date_str: str = intent.parsed_date

    # Use profile lat/lng if available; fall back to Chennai centre
    lat: float = float(profile.get("lat", 13.0827))
    lng: float = float(profile.get("lng", 80.2707))

    async with httpx.AsyncClient(timeout=15.0) as client:
        phq_task = _fetch_predicthq(client, settings, lat, lng, date_str, liked_types)
        tm_task = _fetch_ticketmaster(client, settings, lat, lng, date_str)

        phq_results, tm_results = await asyncio.gather(
            phq_task, tm_task, return_exceptions=True
        )

    # Collect whichever sources succeeded
    combined: list[dict[str, Any]] = []
    if isinstance(phq_results, list):
        combined.extend(phq_results)
    else:
        logger.error("PredictHQ fetch failed: %s", phq_results)

    if isinstance(tm_results, list):
        combined.extend(tm_results)
    else:
        logger.error("Ticketmaster fetch failed: %s", tm_results)

    # Deduplicate by first-20-chars of lowercased name
    seen: set[str] = set()
    deduped: list[dict[str, Any]] = []
    for ev in combined:
        key = ev["name"].lower()[:20]
        if key not in seen:
            seen.add(key)
            deduped.append(ev)

    # Sort ascending by price (cheapest first)
    deduped.sort(key=lambda e: e["price"])

    # Build EventResult objects, filtering by budget
    events: list[EventResult] = []
    for ev in deduped:
        if ev["price"] > intent.parsed_budget:
            continue
        try:
            events.append(
                EventResult(
                    id=ev["id"],
                    name=ev["name"],
                    type=ev["type"],
                    venue=ev["venue"],
                    address=ev["address"],
                    lat=ev["lat"],
                    lng=ev["lng"],
                    start_time=ev["start_time"],
                    price=ev["price"],
                    booking_url=ev["booking_url"],
                    source=ev["source"],
                )
            )
        except Exception as model_err:
            logger.warning("Skipping event that failed model validation: %s", model_err)

        if len(events) >= 8:
            break

    logger.info(
        "event_search returned %d events for (%.4f, %.4f) on %s",
        len(events), lat, lng, date_str,
    )
    return {"events": events}
