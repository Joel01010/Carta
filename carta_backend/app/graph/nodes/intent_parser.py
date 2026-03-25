"""Node 1: intent_parser — Extracts structured intent from natural language.

Uses Gemini with model fallback chain. Also detects the city from the user message.
"""

from __future__ import annotations

import re
from datetime import date, timedelta

from app.config import get_settings
from app.graph.state import GraphState, ParsedIntent, CITY_COORDINATES
from app.utils.gemini import invoke_with_fallback
from app.utils.logger import get_logger

logger = get_logger(__name__)

SYSTEM_PROMPT = """\
You are an intent parser for Carta, a hyper-local evening planner app for Indian cities.

Given the user's chat message and their stored profile, extract the following fields:
- parsed_date: The date the user wants to go out (ISO format YYYY-MM-DD).
  If they say "this Saturday" or "Saturday", compute from today's date ({today}).
  If they say "tomorrow", use tomorrow's date. Default to the next Saturday.
- parsed_time_of_day: One of "morning", "afternoon", "evening", or "night".
  Default to "evening" if not specified.
- parsed_budget: Maximum budget in INR. If not specified, use the user's
  profile budget_max ({budget_max}).
- parsed_constraints: A list of dietary or preference constraints mentioned
  (e.g. ["vegetarian", "no alcohol", "family-friendly"]). Extract only
  explicit constraints; do not infer.
- detected_city: The city the user wants to plan in. Look for explicit city
  mentions in the message. If no city is mentioned, use their profile city: {city}.
  Supported cities: Chennai, Mumbai, Delhi, Bangalore, Hyderabad, Kolkata, Pune,
  Ahmedabad, Jaipur, Goa, Kochi, Coimbatore, Lucknow, Chandigarh, Indore,
  Vizag, Mysore.

User profile context:
- City: {city}
- Preferred cuisines: {cuisines}
- Liked event types: {event_types}
- Default budget: {budget_max} INR
"""


def _next_saturday(today: date) -> date:
    """Return the date of the coming Saturday (or today if already Saturday)."""
    days_ahead = 5 - today.weekday()  # Saturday = 5
    if days_ahead <= 0:
        days_ahead += 7
    return today + timedelta(days=days_ahead)


def _detect_city(message: str, profile_city: str) -> str:
    """Detect city from user message using keyword matching."""
    msg_lower = message.lower()
    for city_name in CITY_COORDINATES:
        # Use word boundary matching to avoid partial matches
        if re.search(rf'\b{re.escape(city_name)}\b', msg_lower):
            return city_name.title()
    return profile_city


async def intent_parser(state: GraphState) -> dict:
    """Parse the user's natural-language message into a structured intent.

    Uses Gemini with model fallback chain. Falls back to sensible defaults
    if all models fail.
    """
    profile = state.get("user_profile") or {}
    today = date.today()
    profile_city = profile.get("city", "Chennai")

    # Quick city detection from message
    detected_city = _detect_city(state.get("user_message", ""), profile_city)

    system = SYSTEM_PROMPT.format(
        today=today.isoformat(),
        city=detected_city,
        cuisines=", ".join(profile.get("preferred_cuisines", [])) or "not set",
        event_types=", ".join(profile.get("liked_event_types", [])) or "not set",
        budget_max=profile.get("budget_max", 2000),
    )

    try:
        parsed: ParsedIntent = await invoke_with_fallback(
            messages=[
                {"role": "system", "content": system},
                {"role": "user", "content": state["user_message"]},
            ],
            temperature=0,
            structured_output=ParsedIntent,
        )
        # Override detected_city if LLM didn't detect one
        if parsed.detected_city == "Chennai" and detected_city != "Chennai":
            parsed.detected_city = detected_city

        logger.info("Parsed intent: date=%s city=%s budget=%d",
                     parsed.parsed_date, parsed.detected_city, parsed.parsed_budget)
        return {"parsed_intent": parsed}

    except Exception as exc:
        logger.error("Intent parsing failed: %s", exc)
        # Fallback to sensible defaults
        fallback = ParsedIntent(
            parsed_date=_next_saturday(today).isoformat(),
            parsed_time_of_day="evening",
            parsed_budget=profile.get("budget_max", 2000),
            parsed_constraints=[],
            detected_city=detected_city,
        )
        return {"parsed_intent": fallback}
