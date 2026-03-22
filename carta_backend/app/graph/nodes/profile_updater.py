"""Node 5: profile_updater — Learns from itinerary interactions."""

from __future__ import annotations

from app.graph.state import GraphState
from app.db.queries import get_user_profile, update_user_profile
from app.utils.logger import get_logger

logger = get_logger(__name__)

# Mapping from stop_type to which profile field it influences
STOP_TYPE_TO_PROFILE_FIELD = {
    "meal": "preferred_cuisines",
    "event": "liked_event_types",
    "drinks": "preferred_cuisines",
}


async def profile_updater(state: GraphState) -> dict:
    """Update user profile preferences based on the generated itinerary.

    This node always runs last. It inspects the stops in the itinerary
    and nudges the user's preference arrays so future plans improve.

    Scoring (simple frequency-based):
    - Each stop type increments the count of relevant cuisine / event type.
    - Future enhancement: also accept explicit 'liked'/'skipped' ratings
      from the /api/rate endpoint.
    """
    user_id = state.get("user_id")
    itinerary = state.get("itinerary")

    if not user_id or not itinerary:
        return {}

    profile = get_user_profile(user_id)
    if not profile:
        logger.warning("profile_updater: no profile found for user %s", user_id)
        return {}

    cuisines: list[str] = list(profile.get("preferred_cuisines") or [])
    event_types: list[str] = list(profile.get("liked_event_types") or [])

    changed = False

    for stop in itinerary.stops:
        # Boost cuisine preferences based on meal/drinks stop names
        if stop.stop_type in ("meal", "drinks"):
            name_lower = stop.name.lower()
            # Simple heuristic: see if stop name hints at a cuisine
            for cuisine_keyword in [
                "biryani", "south indian", "north indian", "chinese",
                "continental", "seafood", "street food", "desserts",
                "japanese", "italian", "mexican", "thai", "korean",
                "cafe", "bakery", "pizza", "burger",
            ]:
                if cuisine_keyword in name_lower:
                    if cuisine_keyword not in cuisines:
                        cuisines.append(cuisine_keyword)
                        changed = True
                    break

        # Boost event type preferences
        if stop.stop_type == "event":
            name_lower = stop.name.lower()
            for event_keyword in [
                "music", "jazz", "rock", "comedy", "theatre", "theater",
                "art", "sports", "nightlife", "food festival", "workshop",
                "standup", "concert", "exhibition", "carnival",
            ]:
                if event_keyword in name_lower:
                    if event_keyword not in event_types:
                        event_types.append(event_keyword)
                        changed = True
                    break

    if changed:
        try:
            update_user_profile(
                user_id,
                {
                    "preferred_cuisines": cuisines,
                    "liked_event_types": event_types,
                },
            )
            logger.info(
                "Updated profile for %s — cuisines: %s, event_types: %s",
                user_id, cuisines, event_types,
            )
        except Exception as exc:
            logger.error("profile_updater DB error: %s", exc)

    return {}
