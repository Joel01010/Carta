"""Carta Backend — FastAPI application entry point."""

from __future__ import annotations

import traceback
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router
from app.config import get_settings
from app.utils.logger import get_logger

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup / shutdown lifecycle."""
    settings = get_settings()
    logger.info("Carta backend starting on port %s", settings.railway_port)
    logger.info(
        "Supabase URL: %s",
        settings.supabase_url[:40] + "..." if settings.supabase_url else "NOT SET",
    )
    logger.info("Gemini primary model: %s", settings.gemini_primary_model)

    # Log optional key status
    for key_name, key_val in [
        ("PredictHQ", settings.predicthq_api_key),
        ("Ticketmaster", settings.ticketmaster_api_key),
        ("Serper", settings.serper_api_key),
        ("OpenRouteService", settings.openrouteservice_api_key),
    ]:
        logger.info("%s: %s", key_name, "configured" if key_val else "NOT SET (disabled)")

    yield
    logger.info("Carta backend shutting down.")


app = FastAPI(
    title="Carta API",
    description="Hyper-local AI evening planner backend for Indian cities.",
    version="1.0.0",
    lifespan=lifespan,
)

# --- CORS (allow all origins) ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Routes ---
app.include_router(router)


# --- Health Endpoint ---
@app.get("/health")
async def health():
    """Health check endpoint with Supabase and Gemini connectivity checks."""
    checks: dict[str, str] = {}

    # Check Supabase
    try:
        from app.db.supabase_client import get_supabase_client
        sb = get_supabase_client()
        sb.table("user_profiles").select("id").limit(1).execute()
        checks["supabase"] = "ok"
    except Exception as exc:
        checks["supabase"] = f"error: {str(exc)[:100]}"

    # Check Gemini
    settings = get_settings()
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                f"https://generativelanguage.googleapis.com/v1beta/models/{settings.gemini_primary_model}",
                params={"key": settings.google_api_key},
            )
            if resp.status_code == 200:
                checks["gemini"] = "ok"
            else:
                checks["gemini"] = f"error: HTTP {resp.status_code}"
    except Exception as exc:
        checks["gemini"] = f"error: {str(exc)[:100]}"

    overall = "ok" if all(v == "ok" for v in checks.values()) else "degraded"

    return {
        "status": overall,
        "version": "1.0.0",
        "checks": checks,
    }
