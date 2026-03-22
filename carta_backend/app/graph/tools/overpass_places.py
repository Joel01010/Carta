"""Overpass API (OpenStreetMap) tool — finds nearby places for the map_scraper agent."""

from __future__ import annotations

import overpy
from langchain_core.tools import tool

from app.utils.logger import get_logger

logger = get_logger(__name__)

# Public Overpass API endpoint — no API key required
OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# Map user-facing place_type values to OSM amenity / tourism tags
_AMENITY_MAP: dict[str, str] = {
    "restaurant": "restaurant",
    "cafe": "cafe",
    "bar": "bar",
    "fuel": "fuel",
    "gas_station": "fuel",
    "attraction": "attraction",       # handled via tourism tag below
    "tourist_attraction": "attraction",
}


@tool
async def find_nearby_places(
    lat: float,
    lng: float,
    place_type: str,
    radius_meters: int = 2000,
    keyword: str | None = None,
) -> list[dict]:
    """Search for nearby places using Overpass API (OpenStreetMap). No API key required.

    Args:
        lat: Latitude of the center point.
        lng: Longitude of the center point.
        place_type: Type of place — restaurant, cafe, bar, fuel, attraction.
        radius_meters: Search radius in meters (default 2000).
        keyword: Optional keyword to narrow results by name (case-insensitive substring match).

    Returns:
        List of dicts with name, address, lat, lng, type. Up to 6 results.
    """
    osm_tag = _AMENITY_MAP.get(place_type.lower(), place_type.lower())

    # Build Overpass QL query
    if osm_tag == "attraction":
        query = f"""
[out:json][timeout:15];
(
  node["tourism"="attraction"](around:{radius_meters},{lat},{lng});
  node["tourism"="museum"](around:{radius_meters},{lat},{lng});
  node["tourism"="artwork"](around:{radius_meters},{lat},{lng});
);
out body 10;
"""
    else:
        query = f"""
[out:json][timeout:15];
node["amenity"="{osm_tag}"](around:{radius_meters},{lat},{lng});
out body 10;
"""

    try:
        api = overpy.Overpass(url=OVERPASS_URL)
        result = api.query(query)
        nodes = result.nodes
    except Exception as exc:
        logger.error("Overpass API error (place_type=%s): %s", place_type, exc)
        return []

    results: list[dict] = []
    for node in nodes[:6]:
        tags = node.tags
        name = tags.get("name", "")
        if not name:
            continue  # Skip unnamed nodes

        # Apply keyword filter if provided
        if keyword and keyword.lower() not in name.lower():
            continue

        address_parts = [
            tags.get("addr:housenumber", ""),
            tags.get("addr:street", ""),
            tags.get("addr:city", ""),
        ]
        address = " ".join(p for p in address_parts if p).strip() or tags.get("addr:full", "")

        results.append(
            {
                "name": name,
                "address": address,
                "lat": float(node.lat),
                "lng": float(node.lon),
                "type": osm_tag,
                "source": "overpass",
            }
        )

        if len(results) >= 6:
            break

    logger.info(
        "find_nearby_places (Overpass) returned %d results near (%.4f, %.4f) type=%s",
        len(results), lat, lng, place_type,
    )
    return results
