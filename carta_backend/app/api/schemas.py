"""Request / Response Pydantic schemas for the FastAPI endpoints."""

from __future__ import annotations

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# POST /api/chat
# ---------------------------------------------------------------------------

class ChatRequest(BaseModel):
    """Request body for the chat endpoint."""
    user_id: str = Field(default="", description="Supabase auth user ID")
    message: str = Field(default="", description="User's chat message")
    previous_itinerary: dict | None = None


class ItineraryStopResponse(BaseModel):
    """A single stop in the itinerary response."""
    time: str = ""
    stop_type: str = ""
    name: str = ""
    address: str = ""
    lat: float = 0.0
    lng: float = 0.0
    cost_estimate: int = 0
    duration_mins: int = 60
    notes: str | None = None
    external_url: str | None = None


class ItineraryResponse(BaseModel):
    """Full itinerary in the chat response."""
    title: str = ""
    date: str = ""
    total_cost_estimate: int = 0
    summary: str = ""
    stops: list[ItineraryStopResponse] = []


class ChatResponse(BaseModel):
    """Response body for the chat endpoint — always 200."""
    reply: str
    itinerary: ItineraryResponse | None = None


# ---------------------------------------------------------------------------
# POST /api/rate
# ---------------------------------------------------------------------------

class RateRequest(BaseModel):
    """Request body for the rate endpoint."""
    user_id: str = Field(default="", description="Supabase auth user ID")
    stop_id: str = ""
    rating: str = Field(default="", pattern=r"^(liked|skipped)$")


class RateResponse(BaseModel):
    """Response body for the rate endpoint."""
    success: bool


# ---------------------------------------------------------------------------
# GET /api/profile/{user_id}
# ---------------------------------------------------------------------------

class UserProfileResponse(BaseModel):
    """Response body for the profile endpoint."""
    id: str = ""
    user_id: str | None = None
    city: str = "Chennai"
    preferred_cuisines: list[str] = []
    liked_event_types: list[str] = []
    budget_max: int = 2000
    max_distance_km: float = 15.0
    home_lat: float | None = None
    home_lng: float | None = None
