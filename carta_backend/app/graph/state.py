"""LangGraph state definition and shared Pydantic models for the Carta pipeline.

Uses Annotated[list, operator.add] for events and places so parallel nodes
can both append without overwriting each other.
"""

from __future__ import annotations

import operator
from typing import Annotated, TypedDict

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Pydantic models (used as structured outputs and in the state)
# ---------------------------------------------------------------------------

class ParsedIntent(BaseModel):
    """Output of Node 1 — intent_parser."""

    parsed_date: str = Field(
        description="ISO-format date string, e.g. '2026-03-28'"
    )
    parsed_time_of_day: str = Field(
        description="Time of day bucket: 'morning', 'afternoon', 'evening', or 'night'"
    )
    parsed_budget: int = Field(
        description="Maximum budget in INR"
    )
    parsed_constraints: list[str] = Field(
        default_factory=list,
        description="Dietary or preference constraints, e.g. ['vegetarian', 'no alcohol']",
    )
    detected_city: str = Field(
        default="Chennai",
        description="City detected from user message",
    )


class EventResult(BaseModel):
    """A single event returned by Node 2 — event_search."""

    id: str = ""
    name: str = ""
    type: str = ""
    venue: str = ""
    address: str = ""
    lat: float = 0.0
    lng: float = 0.0
    start_time: str = ""
    price: int = 0
    booking_url: str = ""
    source: str = "predicthq"


class PlaceResult(BaseModel):
    """A single place returned by Node 3 — map_scraper."""

    name: str = ""
    place_type: str = ""  # restaurant | attraction | fuel
    address: str = ""
    lat: float = 0.0
    lng: float = 0.0
    rating: float | None = None
    price_level: int | None = None
    source: str = ""  # overpass | serper


class ItineraryStop(BaseModel):
    """A single stop within a planned itinerary."""

    time: str = ""
    stop_type: str = ""  # meal | event | drinks | fuel
    name: str = ""
    address: str = ""
    lat: float = 0.0
    lng: float = 0.0
    cost_estimate: int = 0
    duration_mins: int = 60
    notes: str | None = None
    external_url: str | None = None


class ItineraryOutput(BaseModel):
    """Structured output from Node 4 — planner."""

    title: str = ""
    date: str = ""
    total_cost_estimate: int = 0
    summary: str = ""
    stops: list[ItineraryStop] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# City coordinates lookup
# ---------------------------------------------------------------------------

CITY_COORDINATES: dict[str, tuple[float, float]] = {
    "chennai": (13.0827, 80.2707),
    "mumbai": (19.0760, 72.8777),
    "delhi": (28.6139, 77.2090),
    "bangalore": (12.9716, 77.5946),
    "bengaluru": (12.9716, 77.5946),
    "hyderabad": (17.3850, 78.4867),
    "kolkata": (22.5726, 88.3639),
    "pune": (18.5204, 73.8567),
    "ahmedabad": (23.0225, 72.5714),
    "jaipur": (26.9124, 75.7873),
    "goa": (15.2993, 74.1240),
    "kochi": (9.9312, 76.2673),
    "coimbatore": (11.0168, 76.9558),
    "lucknow": (26.8467, 80.9462),
    "chandigarh": (30.7333, 76.7794),
    "indore": (22.7196, 75.8577),
    "vizag": (17.6868, 83.2185),
    "visakhapatnam": (17.6868, 83.2185),
    "mysore": (12.2958, 76.6394),
    "mysuru": (12.2958, 76.6394),
}


def get_city_coords(city: str) -> tuple[float, float]:
    """Return (lat, lng) for a city name. Defaults to Chennai."""
    return CITY_COORDINATES.get(city.lower().strip(), (13.0827, 80.2707))


# ---------------------------------------------------------------------------
# LangGraph TypedDict State
# ---------------------------------------------------------------------------

class GraphState(TypedDict, total=False):
    """Shared state that flows through every node in the LangGraph pipeline.

    events and places use Annotated[list, operator.add] so parallel nodes
    can both append without overwriting each other.
    """

    # --- Inputs (set before graph invocation) ---
    user_id: str
    user_message: str
    user_profile: dict
    previous_itinerary: dict | None

    # --- Node 1 output ---
    parsed_intent: ParsedIntent | None

    # --- Node 2 output (uses reducer for parallel fan-in) ---
    events: Annotated[list[EventResult], operator.add]

    # --- Node 3 output (uses reducer for parallel fan-in) ---
    places: Annotated[list[PlaceResult], operator.add]

    # --- Node 4 output ---
    itinerary: ItineraryOutput | None
    reply_text: str

    # --- Control ---
    error: str | None
