"""Simple in-memory rate limiter — 10 requests per user per minute."""

from __future__ import annotations

import time
from collections import defaultdict

# Configuration
MAX_REQUESTS_PER_MINUTE = 10
WINDOW_SECONDS = 60

# user_id → list of request timestamps
_user_requests: dict[str, list[float]] = defaultdict(list)


def is_rate_limited(user_id: str) -> bool:
    """Return True if the user has exceeded the rate limit."""
    now = time.time()
    cutoff = now - WINDOW_SECONDS

    # Clean old entries
    _user_requests[user_id] = [
        ts for ts in _user_requests[user_id] if ts > cutoff
    ]

    if len(_user_requests[user_id]) >= MAX_REQUESTS_PER_MINUTE:
        return True

    _user_requests[user_id].append(now)
    return False
