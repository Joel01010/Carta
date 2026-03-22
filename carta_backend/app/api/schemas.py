"""Request / Response Pydantic schemas for the FastAPI endpoints."""

from __future__ import annotations

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# POST /api/chat
# ---------------------------------------------------------------------------

class ChatRequest(BaseModel):
    user_id: str
    message: str
    previous_itinerary: dict | None = None


class ItineraryStopResponse(BaseModel):
    time: str
    stop_type: str
    name: str
    address: str
    lat: float
    lng: float
    cost_estimate: int
    duration_mins: int
    notes: str | None = None
    external_url: str | None = None


class ItineraryResponse(BaseModel):
    title: str
    date: str
    total_cost_estimate: int
    summary: str
    stops: list[ItineraryStopResponse]


class ChatResponse(BaseModel):
    reply: str
    itinerary: ItineraryResponse | None = None


# ---------------------------------------------------------------------------
# POST /api/rate
# ---------------------------------------------------------------------------

class RateRequest(BaseModel):
    user_id: str
    stop_id: str
    rating: str = Field(pattern=r"^(liked|skipped)$")


class RateResponse(BaseModel):
    success: bool


# ---------------------------------------------------------------------------
# GET /api/profile/{user_id}
# ---------------------------------------------------------------------------

class UserProfileResponse(BaseModel):
    id: str
    user_id: str | None = None
    city: str
    preferred_cuisines: list[str] = []
    liked_event_types: list[str] = []
    budget_max: int = 2000
    max_distance_km: float = 15.0
    home_lat: float | None = None
    home_lng: float | None = None
