"""Node 4: planner — Builds the final itinerary using Gemini 1.5 Pro."""

from __future__ import annotations

import uuid

from langchain_google_genai import ChatGoogleGenerativeAI

from app.config import get_settings
from app.graph.state import GraphState, ItineraryOutput
from app.db.queries import create_itinerary, create_itinerary_stops, create_cached_places
from app.utils.logger import get_logger

logger = get_logger(__name__)

SYSTEM_PROMPT = """\
You are Carta, a knowledgeable local guide for {city}. You talk like a
well-travelled friend recommending spots — warm, opinionated, and specific.
Use "I've mapped out your evening" style language. Reference actual {city}
landmarks and neighbourhoods naturally.

Build a complete itinerary from the available events and places below.

RULES — follow every single one:
1. Start with a MEAL stop BEFORE the main event.
2. The EVENT is the centerpiece stop. Pick the best match from the events list.
3. Add ONE after-stop (drinks or attraction) ONLY if budget allows.
4. Add a FUEL stop ONLY if one was provided and the event is far from home.
5. Respect ALL constraints: {constraints}
6. Total cost must NOT exceed ₹{budget}.
7. Each stop needs: time, stop_type (meal|event|drinks|fuel), name, address,
   lat, lng, cost_estimate, duration_mins, and optional notes.
8. Provide a catchy title and a 1-2 sentence summary.

USER PROFILE:
- City: {city}
- Preferred cuisines: {cuisines}
- Liked event types: {event_types}
- Budget: ₹{budget}
- Time of day: {time_of_day}
- Date: {date}

AVAILABLE EVENTS:
{events_text}

AVAILABLE PLACES (restaurants, attractions, fuel):
{places_text}
"""

REPLY_PROMPT = """\
Now write a friendly, conversational reply to the user about this itinerary.
Sound like a knowledgeable local friend — not a generic assistant.
Reference specific {city} landmarks or neighbourhoods.
Keep it to 3-4 sentences. Start with a confident opener like
"I've mapped out your evening" or "Here's a solid plan for {date}".

Itinerary:
{itinerary_json}
"""


def _format_events(events: list) -> str:
    if not events:
        return "No events found — suggest a general outing."
    lines = []
    for i, ev in enumerate(events, 1):
        lines.append(
            f"{i}. {ev.name} ({ev.type}) at {ev.venue}, {ev.address} | "
            f"₹{ev.price} | Starts: {ev.start_time} | Booking: {ev.booking_url}"
        )
    return "\n".join(lines)


def _format_places(places: list) -> str:
    if not places:
        return "No specific places found — use your knowledge of the city."
    lines = []
    for i, p in enumerate(places, 1):
        rating = f"Rating: {p.rating}" if p.rating else ""
        lines.append(
            f"{i}. [{p.place_type}] {p.name}, {p.address} ({p.source}) {rating}"
        )
    return "\n".join(lines)


async def planner(state: GraphState) -> dict:
    """Generate the final itinerary, write it to Supabase, and compose the reply."""
    settings = get_settings()
    profile = state.get("user_profile") or {}
    intent = state.get("parsed_intent")
    events = state.get("events", [])
    places = state.get("places", [])

    city = profile.get("city", "Chennai")
    cuisines = profile.get("preferred_cuisines", [])
    event_types = profile.get("liked_event_types", [])
    budget = intent.parsed_budget if intent else profile.get("budget_max", 2000)
    constraints = intent.parsed_constraints if intent else []
    time_of_day = intent.parsed_time_of_day if intent else "evening"
    plan_date = intent.parsed_date if intent else ""

    system = SYSTEM_PROMPT.format(
        city=city,
        cuisines=", ".join(cuisines) or "any",
        event_types=", ".join(event_types) or "any",
        budget=budget,
        constraints=", ".join(constraints) if constraints else "none",
        time_of_day=time_of_day,
        date=plan_date,
        events_text=_format_events(events),
        places_text=_format_places(places),
    )

    llm = ChatGoogleGenerativeAI(
        model="gemini-1.5-pro",
        google_api_key=settings.google_api_key,
        temperature=0.7,
    )
    structured_llm = llm.with_structured_output(ItineraryOutput)

    try:
        itinerary: ItineraryOutput = await structured_llm.ainvoke(
            [
                {"role": "system", "content": system},
                {"role": "user", "content": state["user_message"]},
            ]
        )
    except Exception as exc:
        logger.error("Planner LLM error: %s", exc)
        return {
            "itinerary": None,
            "reply_text": (
                "I hit a snag putting your plan together — could you try again "
                "with a slightly different request?"
            ),
        }

    # Attach external_url from matching events to the event stop
    for stop in itinerary.stops:
        if stop.stop_type == "event":
            for ev in events:
                if ev.name.lower() in stop.name.lower() or stop.name.lower() in ev.name.lower():
                    stop.external_url = ev.booking_url
                    break

    # ----- Persist to Supabase -----
    itinerary_id = str(uuid.uuid4())
    user_id = state["user_id"]

    try:
        create_itinerary(
            {
                "id": itinerary_id,
                "user_id": user_id,
                "date": itinerary.date,
                "total_cost_estimate": itinerary.total_cost_estimate,
                "title": itinerary.title,
                "summary": itinerary.summary,
            }
        )

        stop_rows = []
        for i, stop in enumerate(itinerary.stops):
            stop_rows.append(
                {
                    "id": str(uuid.uuid4()),
                    "itinerary_id": itinerary_id,
                    "sequence_order": i + 1,
                    "time": stop.time,
                    "stop_type": stop.stop_type,
                    "name": stop.name,
                    "address": stop.address,
                    "lat": stop.lat,
                    "lng": stop.lng,
                    "cost_estimate": stop.cost_estimate,
                    "duration_mins": stop.duration_mins,
                    "notes": stop.notes,
                    "external_url": stop.external_url,
                }
            )
        if stop_rows:
            create_itinerary_stops(stop_rows)

        # Persist cached places
        place_rows = []
        for p in places:
            place_rows.append(
                {
                    "id": str(uuid.uuid4()),
                    "itinerary_id": itinerary_id,
                    "place_type": p.place_type,
                    "name": p.name,
                    "address": p.address,
                    "lat": p.lat,
                    "lng": p.lng,
                    "rating": p.rating,
                    "price_level": p.price_level,
                    "source": p.source,
                }
            )
        if place_rows:
            create_cached_places(place_rows)

        logger.info("Persisted itinerary %s with %d stops", itinerary_id, len(stop_rows))

    except Exception as db_exc:
        logger.error("Supabase write error: %s", db_exc)
        # Continue — the itinerary was generated; DB write failure is non-fatal

    # ----- Generate conversational reply -----
    try:
        reply_llm = ChatGoogleGenerativeAI(
            model="gemini-1.5-flash",
            google_api_key=settings.google_api_key,
            temperature=0.8,
        )
        reply_result = await reply_llm.ainvoke(
            [
                {
                    "role": "system",
                    "content": REPLY_PROMPT.format(
                        city=city,
                        date=plan_date,
                        itinerary_json=itinerary.model_dump_json(indent=2),
                    ),
                },
                {"role": "user", "content": "Write the reply."},
            ]
        )
        reply_text = reply_result.content
    except Exception as reply_exc:
        logger.error("Reply generation error: %s", reply_exc)
        reply_text = (
            f"I've mapped out your {time_of_day} — {itinerary.title}! "
            f"{itinerary.summary}"
        )

    return {"itinerary": itinerary, "reply_text": reply_text}
