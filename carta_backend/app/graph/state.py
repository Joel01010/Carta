"""LangGraph state definition and shared Pydantic models for the Carta pipeline."""

from __future__ import annotations

from typing import TypedDict

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


class EventResult(BaseModel):
    """A single event returned by Node 2 — event_search."""

    id: str
    name: str
    type: str
    venue: str
    address: str
    lat: float
    lng: float
    start_time: str
    price: int
    booking_url: str
    source: str = "predicthq"


class PlaceResult(BaseModel):
    """A single place returned by Node 3 — map_scraper."""

    name: str
    place_type: str  # restaurant | attraction | fuel
    address: str
    lat: float
    lng: float
    rating: float | None = None
    price_level: int | None = None
    source: str  # overpass | serper


class ItineraryStop(BaseModel):
    """A single stop within a planned itinerary."""

    time: str
    stop_type: str  # meal | event | drinks | fuel
    name: str
    address: str
    lat: float
    lng: float
    cost_estimate: int
    duration_mins: int
    notes: str | None = None
    external_url: str | None = None


class ItineraryOutput(BaseModel):
    """Structured output from Node 4 — planner."""

    title: str
    date: str
    total_cost_estimate: int
    summary: str
    stops: list[ItineraryStop]


# ---------------------------------------------------------------------------
# LangGraph TypedDict State
# ---------------------------------------------------------------------------

class GraphState(TypedDict, total=False):
    """Shared state that flows through every node in the LangGraph pipeline."""

    # --- Inputs (set before graph invocation) ---
    user_id: str
    user_message: str
    user_profile: dict
    previous_itinerary: dict | None

    # --- Node 1 output ---
    parsed_intent: ParsedIntent | None

    # --- Node 2 output ---
    events: list[EventResult]

    # --- Node 3 output ---
    places: list[PlaceResult]

    # --- Node 4 output ---
    itinerary: ItineraryOutput | None
    reply_text: str

    # --- Control ---
    error: str | None
