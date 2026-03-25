"""FastAPI route handlers for the Carta backend API.

Key contract:
- POST /api/chat → always returns 200 with {"reply": str, "itinerary": obj|null}
- NEVER returns 500
- Missing user_id → 400
"""

from __future__ import annotations

import traceback

from fastapi import APIRouter
from fastapi.responses import JSONResponse

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
from app.utils.logger import get_logger, generate_request_id, hash_message, sanitize_input
from app.utils.cache import get_cached_response, set_cached_response
from app.utils.rate_limiter import is_rate_limited

logger = get_logger(__name__)

router = APIRouter(prefix="/api")


def _validate_user_id(user_id: str | None) -> JSONResponse | None:
    """Return a 400 JSONResponse if user_id is missing or empty, else None."""
    if not user_id or not user_id.strip():
        return JSONResponse(
            status_code=400,
            content={"error": "user_id required"},
        )
    return None


# --------------------------------------------------------------------------
# POST /api/chat
# --------------------------------------------------------------------------

@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """Handle a user chat message and return an AI-generated itinerary.

    Always returns HTTP 200 with {"reply": str, "itinerary": obj|null}.
    Never returns 500.
    """
    request_id = generate_request_id()

    # Validate user_id
    error_resp = _validate_user_id(request.user_id)
    if error_resp:
        return error_resp

    user_id = request.user_id.strip()
    message = request.message.strip() if request.message else ""

    if not message:
        return JSONResponse(
            status_code=400,
            content={"error": "message required"},
        )

    logger.info(
        "[%s] POST /api/chat user=%s msg_hash=%s",
        request_id,
        user_id[:8],
        hash_message(message),
    )

    # Rate limiting
    if is_rate_limited(user_id):
        logger.warning("[%s] Rate limited user=%s", request_id, user_id[:8])
        return ChatResponse(
            reply="You're sending messages too quickly. Please wait a moment and try again.",
            itinerary=None,
        )

    # Check cache
    cached = get_cached_response(user_id, message)
    if cached:
        logger.info("[%s] Returning cached response", request_id)
        return cached

    # Sanitize input
    clean_message = sanitize_input(message)

    # Fetch user profile — if not found, create a minimal default
    profile = get_user_profile(user_id)
    if not profile:
        logger.info("[%s] No profile for user %s, using defaults", request_id, user_id[:8])
        profile = {
            "id": user_id,
            "user_id": user_id,
            "city": "Chennai",
            "preferred_cuisines": [],
            "liked_event_types": [],
            "budget_max": 2000,
            "max_distance_km": 15.0,
            "home_lat": None,
            "home_lng": None,
        }

    # Build initial graph state
    initial_state = {
        "user_id": user_id,
        "user_message": clean_message,
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
        logger.error("[%s] Graph execution error: %s\n%s", request_id, exc, traceback.format_exc())
        return ChatResponse(
            reply="Carta is having trouble right now. Try again.",
            itinerary=None,
        )

    # Build response
    itinerary_resp = None
    if result.get("itinerary"):
        itin = result["itinerary"]
        try:
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
        except Exception as exc:
            logger.error("[%s] Error building itinerary response: %s", request_id, exc)

    reply = result.get("reply_text") or "I couldn't put a plan together this time. Could you try again?"

    response = ChatResponse(reply=reply, itinerary=itinerary_resp)

    # Cache the response
    set_cached_response(user_id, message, response)

    logger.info("[%s] Response sent, itinerary=%s", request_id, itinerary_resp is not None)
    return response


# --------------------------------------------------------------------------
# POST /api/rate
# --------------------------------------------------------------------------

@router.post("/rate", response_model=RateResponse)
async def rate_stop(request: RateRequest):
    """Rate a stop as 'liked' or 'skipped' — feeds the profile updater."""
    # Validate user_id
    error_resp = _validate_user_id(request.user_id)
    if error_resp:
        return error_resp

    try:
        profile = get_user_profile(request.user_id)
        if not profile:
            return JSONResponse(status_code=404, content={"error": "User profile not found."})

        cuisines: list[str] = list(profile.get("preferred_cuisines") or [])
        event_types: list[str] = list(profile.get("liked_event_types") or [])

        update_user_profile(
            request.user_id,
            {
                "preferred_cuisines": cuisines,
                "liked_event_types": event_types,
            },
        )
        logger.info(
            "Recorded rating '%s' for stop %s (user %s)",
            request.rating,
            request.stop_id,
            request.user_id[:8],
        )
        return RateResponse(success=True)

    except Exception as exc:
        logger.error("Rate endpoint error: %s", exc)
        return RateResponse(success=False)


# --------------------------------------------------------------------------
# GET /api/profile/{user_id}
# --------------------------------------------------------------------------

@router.get("/profile/{user_id}", response_model=UserProfileResponse)
async def get_profile(user_id: str):
    """Return the user profile for the given user_id."""
    error_resp = _validate_user_id(user_id)
    if error_resp:
        return error_resp

    profile = get_user_profile(user_id)
    if not profile:
        return JSONResponse(status_code=404, content={"error": "User profile not found."})

    return UserProfileResponse(
        id=profile.get("id", ""),
        user_id=profile.get("user_id"),
        city=profile.get("city", "Chennai"),
        preferred_cuisines=profile.get("preferred_cuisines", []),
        liked_event_types=profile.get("liked_event_types", []),
        budget_max=profile.get("budget_max", 2000),
        max_distance_km=profile.get("max_distance_km", 15.0),
        home_lat=profile.get("home_lat"),
        home_lng=profile.get("home_lng"),
    )
