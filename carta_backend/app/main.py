"""Carta Backend — FastAPI application entry point."""

from __future__ import annotations

from contextlib import asynccontextmanager

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
    logger.info("Supabase URL: %s", settings.supabase_url[:40] + "..." if settings.supabase_url else "NOT SET")
    yield
    logger.info("Carta backend shutting down.")


app = FastAPI(
    title="Carta API",
    description="Hyper-local AI weekend planner backend for Indian cities.",
    version="1.0.0",
    lifespan=lifespan,
)

# --- CORS (allow Flutter app on any origin during development) ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Routes ---
app.include_router(router)


@app.get("/health")
async def health():
    """Health check endpoint for Railway."""
    return {"status": "ok", "service": "carta-backend"}
