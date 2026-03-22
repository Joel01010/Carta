"""Supabase client singleton (uses the service-role key)."""

from supabase import create_client, Client
from functools import lru_cache

from app.config import get_settings


@lru_cache()
def get_supabase_client() -> Client:
    """Return a cached Supabase client using the service-role key."""
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_key)
