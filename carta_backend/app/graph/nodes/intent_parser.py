"""Node 1: intent_parser — Extracts structured intent from natural language."""

from __future__ import annotations

from datetime import date, timedelta

from langchain_google_genai import ChatGoogleGenerativeAI

from app.config import get_settings
from app.graph.state import GraphState, ParsedIntent
from app.utils.logger import get_logger

logger = get_logger(__name__)

SYSTEM_PROMPT = """\
You are an intent parser for Carta, a hyper-local weekend planner app for Indian cities.

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


async def intent_parser(state: GraphState) -> dict:
    """Parse the user's natural-language message into a structured intent."""
    settings = get_settings()
    profile = state.get("user_profile") or {}
    today = date.today()

    system = SYSTEM_PROMPT.format(
        today=today.isoformat(),
        city=profile.get("city", "Chennai"),
        cuisines=", ".join(profile.get("preferred_cuisines", [])) or "not set",
        event_types=", ".join(profile.get("liked_event_types", [])) or "not set",
        budget_max=profile.get("budget_max", 2000),
    )

    llm = ChatGoogleGenerativeAI(
        model="gemini-1.5-flash",
        google_api_key=settings.google_api_key,
        temperature=0,
    )
    structured_llm = llm.with_structured_output(ParsedIntent)

    try:
        parsed: ParsedIntent = await structured_llm.ainvoke(
            [
                {"role": "system", "content": system},
                {"role": "user", "content": state["user_message"]},
            ]
        )
        logger.info("Parsed intent: %s", parsed.model_dump_json(indent=2))
        return {"parsed_intent": parsed}

    except Exception as exc:
        logger.error("Intent parsing failed: %s", exc)
        # Fallback to sensible defaults
        fallback = ParsedIntent(
            parsed_date=_next_saturday(today).isoformat(),
            parsed_time_of_day="evening",
            parsed_budget=profile.get("budget_max", 2000),
            parsed_constraints=[],
        )
        return {"parsed_intent": fallback}
