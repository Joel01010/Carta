"""Gemini LLM helpers — model fallback chain and retry logic."""

from __future__ import annotations

import asyncio
from typing import Any

from langchain_google_genai import ChatGoogleGenerativeAI

from app.config import get_settings
from app.utils.logger import get_logger

logger = get_logger(__name__)

# Retry configuration
MAX_RETRIES = 3
BASE_BACKOFF_SECONDS = 1.0


def get_model_chain() -> list[str]:
    """Return the ordered model fallback chain."""
    settings = get_settings()
    return [
        settings.gemini_primary_model,
        settings.gemini_fallback_model,
        settings.gemini_last_resort_model,
    ]


def create_llm(model: str, temperature: float = 0.0) -> ChatGoogleGenerativeAI:
    """Create a Gemini LLM instance with the given model name."""
    settings = get_settings()
    return ChatGoogleGenerativeAI(
        model=model,
        google_api_key=settings.google_api_key,
        temperature=temperature,
    )


async def invoke_with_fallback(
    messages: list[dict[str, str]],
    temperature: float = 0.0,
    structured_output: Any = None,
) -> Any:
    """Invoke Gemini with model fallback chain and exponential backoff on 429s.

    Tries each model in the chain. For each model, retries up to MAX_RETRIES
    times with exponential backoff on rate limit (429) errors.

    Args:
        messages: Chat messages to send.
        temperature: LLM temperature.
        structured_output: Optional Pydantic model for structured output.

    Returns:
        The LLM response (or structured output instance).

    Raises:
        Exception: If all models and retries are exhausted.
    """
    models = get_model_chain()
    last_error: Exception | None = None

    for model_name in models:
        llm = create_llm(model_name, temperature)
        if structured_output:
            llm = llm.with_structured_output(structured_output)

        for attempt in range(MAX_RETRIES):
            try:
                result = await llm.ainvoke(messages)
                if attempt > 0 or model_name != models[0]:
                    logger.info(
                        "LLM call succeeded on model=%s attempt=%d",
                        model_name,
                        attempt + 1,
                    )
                return result

            except Exception as exc:
                last_error = exc
                exc_str = str(exc).lower()

                # Check for rate limit (429) or quota errors
                is_rate_limit = "429" in exc_str or "resource_exhausted" in exc_str or "quota" in exc_str
                # Check for model not found (404)
                is_not_found = "404" in exc_str or "not found" in exc_str

                if is_not_found:
                    logger.warning(
                        "Model %s not found (404), trying next model. Error: %s",
                        model_name,
                        str(exc)[:200],
                    )
                    break  # Skip to next model immediately

                if is_rate_limit and attempt < MAX_RETRIES - 1:
                    backoff = BASE_BACKOFF_SECONDS * (2 ** attempt)
                    logger.warning(
                        "Rate limited on %s (attempt %d/%d), backing off %.1fs",
                        model_name,
                        attempt + 1,
                        MAX_RETRIES,
                        backoff,
                    )
                    await asyncio.sleep(backoff)
                    continue

                if not is_rate_limit:
                    logger.error(
                        "LLM error on %s (attempt %d/%d): %s",
                        model_name,
                        attempt + 1,
                        MAX_RETRIES,
                        str(exc)[:200],
                    )
                    break  # Non-retryable error, try next model

        logger.warning("Exhausted retries for model %s, trying next.", model_name)

    raise last_error or RuntimeError("All Gemini models exhausted.")
