"""Simple in-memory response cache with TTL for the Carta backend."""

from __future__ import annotations

import hashlib
import time
from typing import Any

from app.utils.logger import get_logger

logger = get_logger(__name__)

# Cache TTL in seconds (5 minutes)
CACHE_TTL = 300

# In-memory cache: key → (timestamp, value)
_cache: dict[str, tuple[float, Any]] = {}


def _make_key(user_id: str, message: str) -> str:
    """Create a cache key from user_id and message."""
    raw = f"{user_id}:{message.strip().lower()}"
    return hashlib.sha256(raw.encode()).hexdigest()


def get_cached_response(user_id: str, message: str) -> Any | None:
    """Return cached response if available and not expired, else None."""
    key = _make_key(user_id, message)
    entry = _cache.get(key)
    if entry is None:
        return None

    ts, value = entry
    if time.time() - ts > CACHE_TTL:
        del _cache[key]
        return None

    logger.info("Cache HIT for user=%s", user_id[:8])
    return value


def set_cached_response(user_id: str, message: str, value: Any) -> None:
    """Store a response in the cache."""
    key = _make_key(user_id, message)
    _cache[key] = (time.time(), value)

    # Evict expired entries periodically (keep cache bounded)
    if len(_cache) > 500:
        now = time.time()
        expired = [k for k, (ts, _) in _cache.items() if now - ts > CACHE_TTL]
        for k in expired:
            del _cache[k]
