"""Application configuration loaded from environment variables via pydantic-settings.

Required keys crash on missing: GOOGLE_API_KEY, SUPABASE_URL, SUPABASE_KEY.
Optional keys log a warning but allow the app to start.
"""

from __future__ import annotations

import logging
import sys
from functools import lru_cache

from pydantic_settings import BaseSettings

logger = logging.getLogger("carta.config")


class Settings(BaseSettings):
    """All environment variables required by the Carta backend."""

    # --- Required external API keys (crash if missing) ---
    google_api_key: str  # Gemini — no default, must be set
    supabase_url: str  # no default, must be set
    supabase_key: str  # Service-role key — no default, must be set

    # --- Optional API keys (warn if missing) ---
    predicthq_api_key: str = ""
    ticketmaster_api_key: str = ""
    openrouteservice_api_key: str = ""
    serper_api_key: str = ""

    # --- Supabase extras ---
    supabase_db_url: str = ""

    # --- PowerSync ---
    powersync_url: str = ""

    # --- Server ---
    railway_port: int = 8000

    # --- Gemini model fallback chain ---
    gemini_primary_model: str = "gemini-2.5-flash"
    gemini_fallback_model: str = "gemini-2.0-flash"
    gemini_last_resort_model: str = "gemini-2.0-flash-lite"

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
    }


@lru_cache()
def get_settings() -> Settings:
    """Return a cached singleton of the application settings.

    Validates required keys and warns about missing optional keys at startup.
    """
    try:
        settings = Settings()  # type: ignore[call-arg]
    except Exception as exc:
        logger.critical(
            "FATAL: Required environment variable(s) missing — %s. "
            "Set GOOGLE_API_KEY, SUPABASE_URL, and SUPABASE_KEY.",
            exc,
        )
        sys.exit(1)

    # Warn about missing optional keys
    optional_keys = {
        "predicthq_api_key": "PREDICTHQ_API_KEY",
        "ticketmaster_api_key": "TICKETMASTER_API_KEY",
        "serper_api_key": "SERPER_API_KEY",
        "openrouteservice_api_key": "OPENROUTESERVICE_API_KEY",
    }
    for attr, env_name in optional_keys.items():
        if not getattr(settings, attr):
            logger.warning(
                "Optional env var %s is not set — %s functionality disabled.",
                env_name,
                attr.replace("_api_key", ""),
            )

    return settings
