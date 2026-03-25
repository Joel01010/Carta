"""Database query helpers for all Supabase tables.

All queries are wrapped in try/except to prevent DB errors from crashing the app.
"""

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
    try:
        sb = get_supabase_client()
        if sb is None:
            return None
        result = sb.table("user_profiles").select("*").eq("user_id", user_id).execute()
        if result.data:
            return result.data[0]
        return None
    except Exception as exc:
        logger.error("get_user_profile error for %s: %s", user_id[:8], exc)
        return None


def update_user_profile(user_id: str, updates: dict[str, Any]) -> dict | None:
    """Patch fields on the user_profiles row for the given user_id."""
    try:
        sb = get_supabase_client()
        if sb is None:
            return None
        result = (
            sb.table("user_profiles")
            .update(updates)
            .eq("user_id", user_id)
            .execute()
        )
        if result.data:
            return result.data[0]
        return None
    except Exception as exc:
        logger.error("update_user_profile error for %s: %s", user_id[:8], exc)
        return None


# ---------------------------------------------------------------------------
# Itineraries
# ---------------------------------------------------------------------------

def create_itinerary(payload: dict[str, Any]) -> dict | None:
    """Insert a new itinerary row and return the created record."""
    try:
        sb = get_supabase_client()
        if sb is None:
            return None
        result = sb.table("itineraries").insert(payload).execute()
        logger.info("Created itinerary %s for user %s", payload.get("id"), str(payload.get("user_id", ""))[:8])
        return result.data[0] if result.data else None
    except Exception as exc:
        logger.error("create_itinerary error: %s", exc)
        return None


def get_itineraries_for_user(user_id: str) -> list[dict]:
    """Return all current/future itineraries for a user, ordered by date."""
    try:
        sb = get_supabase_client()
        if sb is None:
            return []
        result = (
            sb.table("itineraries")
            .select("*")
            .eq("user_id", user_id)
            .order("date")
            .execute()
        )
        return result.data or []
    except Exception as exc:
        logger.error("get_itineraries_for_user error: %s", exc)
        return []


# ---------------------------------------------------------------------------
# Itinerary Stops
# ---------------------------------------------------------------------------

def create_itinerary_stops(stops: list[dict[str, Any]]) -> list[dict]:
    """Bulk-insert a list of itinerary stop rows."""
    try:
        sb = get_supabase_client()
        if sb is None:
            return []
        result = sb.table("itinerary_stops").insert(stops).execute()
        logger.info("Inserted %d itinerary stops", len(stops))
        return result.data or []
    except Exception as exc:
        logger.error("create_itinerary_stops error: %s", exc)
        return []


def get_stops_for_itinerary(itinerary_id: str) -> list[dict]:
    """Return all stops for an itinerary, ordered by sequence_order."""
    try:
        sb = get_supabase_client()
        if sb is None:
            return []
        result = (
            sb.table("itinerary_stops")
            .select("*")
            .eq("itinerary_id", itinerary_id)
            .order("sequence_order")
            .execute()
        )
        return result.data or []
    except Exception as exc:
        logger.error("get_stops_for_itinerary error: %s", exc)
        return []


# ---------------------------------------------------------------------------
# Cached Places
# ---------------------------------------------------------------------------

def create_cached_places(places: list[dict[str, Any]]) -> list[dict]:
    """Bulk-insert cached place rows."""
    try:
        sb = get_supabase_client()
        if sb is None:
            return []
        result = sb.table("cached_places").insert(places).execute()
        logger.info("Cached %d places", len(places))
        return result.data or []
    except Exception as exc:
        logger.error("create_cached_places error: %s", exc)
        return []


# ---------------------------------------------------------------------------
# Booking Status
# ---------------------------------------------------------------------------

def get_bookings_for_user(user_id: str, limit: int = 20) -> list[dict]:
    """Return recent bookings for a user."""
    try:
        sb = get_supabase_client()
        if sb is None:
            return []
        result = (
            sb.table("booking_status")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return result.data or []
    except Exception as exc:
        logger.error("get_bookings_for_user error: %s", exc)
        return []


def update_booking_status(booking_id: str, status: str) -> dict | None:
    """Update the status of a booking record."""
    try:
        sb = get_supabase_client()
        if sb is None:
            return None
        result = (
            sb.table("booking_status")
            .update({"status": status})
            .eq("id", booking_id)
            .execute()
        )
        if result.data:
            return result.data[0]
        return None
    except Exception as exc:
        logger.error("update_booking_status error: %s", exc)
        return None
