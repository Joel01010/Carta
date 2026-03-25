"""Serper API tool — web search for attractions and local context.

Skips silently if SERPER_API_KEY is not set.
"""

from __future__ import annotations

import httpx
from langchain_core.tools import tool

from app.config import get_settings
from app.utils.logger import get_logger

logger = get_logger(__name__)

SERPER_URL = "https://google.serper.dev/search"


@tool
async def search_web_for_attractions(query: str) -> list[dict]:
    """Search the web for local attractions and contextual information.

    Uses Serper (Google Search API) to find relevant snippets.
    Returns empty list if SERPER_API_KEY is not configured.

    Args:
        query: Search query, e.g. 'best rooftop bars near Marina Beach Chennai'.

    Returns:
        Top 3 results as list of dicts with title, snippet, link.
    """
    settings = get_settings()

    if not settings.serper_api_key:
        logger.info("Serper API key not set — skipping web search.")
        return []

    headers = {
        "X-API-KEY": settings.serper_api_key,
        "Content-Type": "application/json",
    }
    payload = {
        "q": query,
        "gl": "in",
        "hl": "en",
        "num": 5,
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(SERPER_URL, json=payload, headers=headers)
            resp.raise_for_status()
            data = resp.json()
    except Exception as exc:
        logger.error("Serper API error: %s", exc)
        return []

    results = []
    for item in data.get("organic", [])[:3]:
        results.append({
            "title": item.get("title", ""),
            "snippet": item.get("snippet", ""),
            "link": item.get("link", ""),
        })

    logger.info("search_web_for_attractions: %d results for '%s'", len(results), query)
    return results
