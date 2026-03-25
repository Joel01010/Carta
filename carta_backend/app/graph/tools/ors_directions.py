"""OpenRouteService Directions + Overpass fuel-stop tool.

Uses httpx async instead of synchronous overpy to avoid blocking the event loop.
"""

from __future__ import annotations

import httpx
from langchain_core.tools import tool

from app.config import get_settings
from app.utils.logger import get_logger

logger = get_logger(__name__)

ORS_DIRECTIONS_URL = "https://api.openrouteservice.org/v2/directions/driving-car"
OVERPASS_URL = "https://overpass-api.de/api/interpreter"


@tool
async def find_fuel_stops_on_route(
    origin_lat: float,
    origin_lng: float,
    dest_lat: float,
    dest_lng: float,
) -> list[dict]:
    """Find fuel stations near the midpoint of a driving route.

    Uses OpenRouteService for the route midpoint, then Overpass for fuel nodes.

    Args:
        origin_lat: Latitude of origin (user home).
        origin_lng: Longitude of origin.
        dest_lat: Latitude of destination (event venue).
        dest_lng: Longitude of destination.

    Returns:
        List of dicts with name, address, lat, lng (up to 3 results).
    """
    settings = get_settings()

    # Fallback midpoint
    mid_lat = (origin_lat + dest_lat) / 2
    mid_lng = (origin_lng + dest_lng) / 2

    # Step 1: Try to get route midpoint from ORS
    if settings.openrouteservice_api_key:
        try:
            async with httpx.AsyncClient(timeout=12.0) as client:
                resp = await client.post(
                    ORS_DIRECTIONS_URL,
                    headers={
                        "Authorization": settings.openrouteservice_api_key,
                        "Content-Type": "application/json",
                    },
                    json={
                        "coordinates": [
                            [origin_lng, origin_lat],
                            [dest_lng, dest_lat],
                        ],
                        "geometry": True,
                        "geometry_format": "geojson",
                    },
                )
                resp.raise_for_status()
                ors_data = resp.json()

            coords = (
                ors_data.get("routes", [{}])[0]
                .get("geometry", {})
                .get("coordinates", [])
            )
            if coords:
                mid_idx = len(coords) // 2
                mid_lng, mid_lat = coords[mid_idx][0], coords[mid_idx][1]
                logger.info("ORS midpoint: (%.5f, %.5f)", mid_lat, mid_lng)

        except Exception as exc:
            logger.error("ORS Directions API error: %s — using arithmetic midpoint", exc)

    # Step 2: Query Overpass for fuel nodes near midpoint (async)
    query = f"""
[out:json][timeout:10];
node["amenity"="fuel"](around:2000,{mid_lat},{mid_lng});
out body 3;
"""
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(OVERPASS_URL, data={"data": query})
            resp.raise_for_status()
            data = resp.json()
    except Exception as exc:
        logger.error("Overpass fuel search error: %s", exc)
        return []

    fuel_stops: list[dict] = []
    for element in data.get("elements", [])[:3]:
        tags = element.get("tags", {})
        name = tags.get("name", tags.get("brand", "Fuel Station"))
        address_parts = [
            tags.get("addr:housenumber", ""),
            tags.get("addr:street", ""),
        ]
        address = " ".join(p for p in address_parts if p).strip() or ""

        fuel_stops.append({
            "name": name,
            "address": address,
            "lat": float(element.get("lat", 0)),
            "lng": float(element.get("lon", 0)),
            "source": "overpass",
        })

    logger.info(
        "find_fuel_stops_on_route: %d stations near midpoint (%.4f, %.4f)",
        len(fuel_stops), mid_lat, mid_lng,
    )
    return fuel_stops
