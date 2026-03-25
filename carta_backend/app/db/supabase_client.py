"""Supabase client singleton (uses the service-role key)."""

from __future__ import annotations

from functools import lru_cache

from app.config import get_settings
from app.utils.logger import get_logger

logger = get_logger(__name__)


@lru_cache()
def get_supabase_client():
    """Return a cached Supabase client using the service-role key.

    Returns None if Supabase credentials are not configured (should not happen
    since they are required, but handle gracefully).
    """
    settings = get_settings()

    if not settings.supabase_url or not settings.supabase_key:
        logger.error("Supabase URL or key not configured — DB operations will fail.")
        return None

    try:
        from supabase import create_client
        client = create_client(settings.supabase_url, settings.supabase_key)
        logger.info("Supabase client initialised for %s", settings.supabase_url[:40])
        return client
    except Exception as exc:
        logger.error("Failed to create Supabase client: %s", exc)
        return None
