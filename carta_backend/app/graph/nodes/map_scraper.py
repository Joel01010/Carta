"""Node 3: map_scraper — ReAct sub-agent that gathers places via tools."""

from __future__ import annotations

import math

from langchain_google_genai import ChatGoogleGenerativeAI
from langgraph.prebuilt import create_react_agent

from app.config import get_settings
from app.graph.state import GraphState, PlaceResult
from app.graph.tools.overpass_places import find_nearby_places
from app.graph.tools.ors_directions import find_fuel_stops_on_route
from app.graph.tools.serper_search import search_web_for_attractions
from app.utils.logger import get_logger

logger = get_logger(__name__)

# Chennai city centre as a default anchor point
CHENNAI_LAT = 13.0827
CHENNAI_LNG = 80.2707

AGENT_SYSTEM = """\
You are a local place finder for Chennai, India.
Your job is to fetch relevant places for planning a user's outing.

User preferences:
- Preferred cuisines: {cuisines}
- Budget: ₹{budget}
- Constraints: {constraints}
- Home location: ({home_lat}, {home_lng})

Instructions:
1. Search for restaurants matching the user's cuisine preferences near the
   city centre or near the event venue if provided.
2. Find 1-2 nearby attractions or interesting spots.
3. Only search for fuel stops if the event venue is more than 10 km from the
   user's home location.
4. Make at most 4 tool calls total.
"""


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


async def map_scraper(state: GraphState) -> dict:
    """Run the ReAct agent with Overpass (OSM) + ORS + Serper tools.

    Runs in parallel with event_search (Node 2).
    """
    settings = get_settings()
    profile = state.get("user_profile") or {}
    intent = state.get("parsed_intent")

    home_lat = profile.get("home_lat") or CHENNAI_LAT
    home_lng = profile.get("home_lng") or CHENNAI_LNG
    cuisines = profile.get("preferred_cuisines", [])
    constraints = intent.parsed_constraints if intent else []
    budget = intent.parsed_budget if intent else profile.get("budget_max", 2000)

    system_prompt = AGENT_SYSTEM.format(
        cuisines=", ".join(cuisines) if cuisines else "any",
        budget=budget,
        constraints=", ".join(constraints) if constraints else "none",
        home_lat=home_lat,
        home_lng=home_lng,
    )

    llm = ChatGoogleGenerativeAI(
        model="gemini-1.5-flash",
        google_api_key=settings.google_api_key,
        temperature=0,
    )

    tools = [find_nearby_places, find_fuel_stops_on_route, search_web_for_attractions]

    agent = create_react_agent(
        model=llm,
        tools=tools,
        prompt=system_prompt,
    )

    # Build the user message for the agent, including context about events
    events_context = ""
    events = state.get("events", [])
    if events:
        top = events[0]
        events_context = (
            f"The main event is '{top.name}' at ({top.lat}, {top.lng}). "
        )

    user_msg = (
        f"{events_context}"
        f"Find restaurants for cuisines: {', '.join(cuisines) if cuisines else 'any good food'}. "
        f"Also find 1-2 interesting attractions nearby. "
    )

    # Check if fuel stops are needed
    if events:
        dist = _haversine_km(home_lat, home_lng, events[0].lat, events[0].lng)
        if dist > 10:
            user_msg += (
                f"The event is {dist:.1f} km from home. "
                f"Please also find fuel stops on the route from ({home_lat}, {home_lng}) "
                f"to ({events[0].lat}, {events[0].lng})."
            )

    try:
        result = await agent.ainvoke({"messages": [{"role": "user", "content": user_msg}]})
        messages = result.get("messages", [])
    except Exception as exc:
        logger.error("map_scraper agent error: %s", exc)
        return {"places": []}

    # Parse tool call results from the agent's message history
    places: list[PlaceResult] = []

    for msg in messages:
        # Check for tool messages that contain results
        if hasattr(msg, "type") and msg.type == "tool":
            content = msg.content if isinstance(msg.content, list) else []
            if isinstance(msg.content, str):
                # Try to parse string content
                try:
                    import json
                    content = json.loads(msg.content)
                except (json.JSONDecodeError, TypeError):
                    continue

            if not isinstance(content, list):
                continue

            for item in content:
                if not isinstance(item, dict):
                    continue

                # Determine place_type from fields present
                if "rating" in item or "price_level" in item:
                    place_type = "restaurant"
                    source = "overpass"
                elif "snippet" in item:
                    # Serper result — treat as attraction
                    places.append(
                        PlaceResult(
                            name=item.get("title", "Unknown"),
                            place_type="attraction",
                            address=item.get("snippet", ""),
                            lat=home_lat,
                            lng=home_lng,
                            source="serper",
                        )
                    )
                    continue
                elif "name" in item and "address" in item and "rating" not in item:
                    place_type = "fuel"
                    source = "overpass"
                else:
                    place_type = "restaurant"
                    source = "overpass"

                places.append(
                    PlaceResult(
                        name=item.get("name", "Unknown"),
                        place_type=place_type,
                        address=item.get("address", ""),
                        lat=item.get("lat", 0.0),
                        lng=item.get("lng", 0.0),
                        rating=item.get("rating"),
                        price_level=item.get("price_level"),
                        source=source,
                    )
                )

    logger.info("map_scraper returned %d places", len(places))
    return {"places": places}
