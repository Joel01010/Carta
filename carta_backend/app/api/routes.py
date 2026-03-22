"""FastAPI route handlers for the Carta backend API."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from app.api.schemas import (
    ChatRequest,
    ChatResponse,
    ItineraryResponse,
    ItineraryStopResponse,
    RateRequest,
    RateResponse,
    UserProfileResponse,
)
from app.graph.graph import carta_graph
from app.db.queries import get_user_profile, update_user_profile
from app.utils.logger import get_logger

logger = get_logger(__name__)

router = APIRouter(prefix="/api")


# --------------------------------------------------------------------------
# POST /api/chat
# --------------------------------------------------------------------------

@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """Handle a user chat message and return an AI-generated itinerary."""

    # Fetch user profile for context
    profile = get_user_profile(request.user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="User profile not found. Complete onboarding first.")

    # Build initial graph state
    initial_state = {
        "user_id": request.user_id,
        "user_message": request.message,
        "user_profile": profile,
        "previous_itinerary": request.previous_itinerary,
        "parsed_intent": None,
        "events": [],
        "places": [],
        "itinerary": None,
        "reply_text": "",
        "error": None,
    }

    try:
        result = await carta_graph.ainvoke(initial_state)
    except Exception as exc:
        logger.error("Graph execution error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to generate plan. Please try again.")

    # Build response
    itinerary_resp = None
    if result.get("itinerary"):
        itin = result["itinerary"]
        itinerary_resp = ItineraryResponse(
            title=itin.title,
            date=itin.date,
            total_cost_estimate=itin.total_cost_estimate,
            summary=itin.summary,
            stops=[
                ItineraryStopResponse(
                    time=s.time,
                    stop_type=s.stop_type,
                    name=s.name,
                    address=s.address,
                    lat=s.lat,
                    lng=s.lng,
                    cost_estimate=s.cost_estimate,
                    duration_mins=s.duration_mins,
                    notes=s.notes,
                    external_url=s.external_url,
                )
                for s in itin.stops
            ],
        )

    reply = result.get("reply_text", "I couldn't put a plan together this time. Could you try again?")

    return ChatResponse(reply=reply, itinerary=itinerary_resp)


# --------------------------------------------------------------------------
# POST /api/rate
# --------------------------------------------------------------------------

@router.post("/rate", response_model=RateResponse)
async def rate_stop(request: RateRequest):
    """Rate a stop as 'liked' or 'skipped' — feeds the profile updater."""

    profile = get_user_profile(request.user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="User profile not found.")

    cuisines: list[str] = list(profile.get("preferred_cuisines") or [])
    event_types: list[str] = list(profile.get("liked_event_types") or [])

    # For now, we record the rating intent. A more sophisticated approach
    # would look up the stop details and adjust weights.
    # This lightweight version just logs it and flags the profile as updated.
    try:
        update_user_profile(
            request.user_id,
            {
                "preferred_cuisines": cuisines,
                "liked_event_types": event_types,
            },
        )
        logger.info(
            "Recorded rating '%s' for stop %s (user %s)",
            request.rating, request.stop_id, request.user_id,
        )
        return RateResponse(success=True)

    except Exception as exc:
        logger.error("Rate endpoint error: %s", exc)
        raise HTTPException(status_code=500, detail="Failed to record rating.")


# --------------------------------------------------------------------------
# GET /api/profile/{user_id}
# --------------------------------------------------------------------------

@router.get("/profile/{user_id}", response_model=UserProfileResponse)
async def get_profile(user_id: str):
    """Return the user profile for the given user_id."""

    profile = get_user_profile(user_id)
    if not profile:
        raise HTTPException(status_code=404, detail="User profile not found.")

    return UserProfileResponse(
        id=profile["id"],
        user_id=profile.get("user_id"),
        city=profile.get("city", "Chennai"),
        preferred_cuisines=profile.get("preferred_cuisines", []),
        liked_event_types=profile.get("liked_event_types", []),
        budget_max=profile.get("budget_max", 2000),
        max_distance_km=profile.get("max_distance_km", 15.0),
        home_lat=profile.get("home_lat"),
        home_lng=profile.get("home_lng"),
    )
