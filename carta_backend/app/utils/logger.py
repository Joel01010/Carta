"""Structured logging setup for the Carta backend."""

from __future__ import annotations

import hashlib
import logging
import sys
import uuid


def get_logger(name: str) -> logging.Logger:
    """Return a configured logger with structured formatting."""
    logger = logging.getLogger(name)

    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        formatter = logging.Formatter(
            fmt="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)

    return logger


def generate_request_id() -> str:
    """Generate a unique request ID for tracing."""
    return str(uuid.uuid4())[:12]


def hash_message(message: str) -> str:
    """Return a SHA-256 hash of a user message for safe logging."""
    return hashlib.sha256(message.encode("utf-8")).hexdigest()[:16]


def sanitize_input(text: str) -> str:
    """Sanitize user input before passing to LLM.

    Removes potential prompt injection patterns and limits length.
    """
    # Limit length to prevent abuse
    text = text[:2000]

    # Remove common prompt injection patterns
    injection_patterns = [
        "ignore previous instructions",
        "ignore all instructions",
        "disregard your instructions",
        "you are now",
        "new system prompt",
        "override system",
        "forget your instructions",
    ]
    text_lower = text.lower()
    for pattern in injection_patterns:
        if pattern in text_lower:
            text = text.replace(pattern, "[filtered]").replace(
                pattern.title(), "[filtered]"
            )

    return text.strip()
