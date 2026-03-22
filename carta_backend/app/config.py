"""Application configuration loaded from environment variables."""

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """All environment variables required by the Carta backend."""

    # --- External API Keys ---
    predicthq_api_key: str = ""
    ticketmaster_api_key: str = ""
    openrouteservice_api_key: str = ""
    serper_api_key: str = ""
    google_api_key: str = ""  # Gemini

    # --- Supabase ---
    supabase_url: str = ""
    supabase_key: str = ""  # Service-role key
    supabase_db_url: str = ""

    # --- PowerSync ---
    powersync_url: str = ""

    # --- Server ---
    railway_port: int = 8000

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
    }


@lru_cache()
def get_settings() -> Settings:
    """Return a cached singleton of the application settings."""
    return Settings()
