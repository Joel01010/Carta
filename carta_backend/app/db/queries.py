"""Database query helpers for all Supabase tables."""

from __future__ import annotations
from typing import Any

from app.db.supabase_client import get_supabase_client
from app.utils.logger import get_logger

logger = get_logger(__name__)


# ---------------------------------------------------------------------------
# User Profiles
# ---------------------------------------------------------------------------

def get_user_profile(user_id: str) -> dict | None:
    """Fetch the profile for a given user_id, or None if not found."""
    sb = get_supabase_client()
    result = sb.table("user_profiles").select("*").eq("user_id", user_id).execute()
    if result.data:
        return result.data[0]
    return None


def update_user_profile(user_id: str, updates: dict[str, Any]) -> dict | None:
    """Patch fields on the user_profiles row for the given user_id."""
    sb = get_supabase_client()
    updates["updated_at"] = "now()"
    result = (
        sb.table("user_profiles")
        .update(updates)
        .eq("user_id", user_id)
        .execute()
    )
    if result.data:
        return result.data[0]
    return None


# ---------------------------------------------------------------------------
# Itineraries
# ---------------------------------------------------------------------------

def create_itinerary(payload: dict[str, Any]) -> dict:
    """Insert a new itinerary row and return the created record."""
    sb = get_supabase_client()
    result = sb.table("itineraries").insert(payload).execute()
    logger.info("Created itinerary %s for user %s", payload.get("id"), payload.get("user_id"))
    return result.data[0]


def get_itineraries_for_user(user_id: str) -> list[dict]:
    """Return all current/future itineraries for a user, ordered by date."""
    sb = get_supabase_client()
    result = (
        sb.table("itineraries")
        .select("*")
        .eq("user_id", user_id)
        .gte("date", "now()")
        .order("date")
        .execute()
    )
    return result.data


# ---------------------------------------------------------------------------
# Itinerary Stops
# ---------------------------------------------------------------------------

def create_itinerary_stops(stops: list[dict[str, Any]]) -> list[dict]:
    """Bulk-insert a list of itinerary stop rows."""
    sb = get_supabase_client()
    result = sb.table("itinerary_stops").insert(stops).execute()
    logger.info("Inserted %d itinerary stops", len(stops))
    return result.data


def get_stops_for_itinerary(itinerary_id: str) -> list[dict]:
    """Return all stops for an itinerary, ordered by sequence_order."""
    sb = get_supabase_client()
    result = (
        sb.table("itinerary_stops")
        .select("*")
        .eq("itinerary_id", itinerary_id)
        .order("sequence_order")
        .execute()
    )
    return result.data


# ---------------------------------------------------------------------------
# Cached Places
# ---------------------------------------------------------------------------

def create_cached_places(places: list[dict[str, Any]]) -> list[dict]:
    """Bulk-insert cached place rows."""
    sb = get_supabase_client()
    result = sb.table("cached_places").insert(places).execute()
    logger.info("Cached %d places", len(places))
    return result.data


# ---------------------------------------------------------------------------
# Booking Status
# ---------------------------------------------------------------------------

def get_bookings_for_user(user_id: str, limit: int = 20) -> list[dict]:
    """Return recent bookings for a user."""
    sb = get_supabase_client()
    result = (
        sb.table("booking_status")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(limit)
        .execute()
    )
    return result.data


def update_booking_status(booking_id: str, status: str) -> dict | None:
    """Update the status of a booking record."""
    sb = get_supabase_client()
    result = (
        sb.table("booking_status")
        .update({"status": status, "updated_at": "now()"})
        .eq("id", booking_id)
        .execute()
    )
    if result.data:
        return result.data[0]
    return None
