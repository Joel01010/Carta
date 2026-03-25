"""Tests for the FastAPI endpoints."""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_endpoint():
    """Health check should return 200 with status and version."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] in ("ok", "degraded")
    assert data["version"] == "1.0.0"
    assert "checks" in data


def test_chat_missing_user_id_returns_400():
    """POST /api/chat without user_id should return 400."""
    response = client.post(
        "/api/chat",
        json={
            "message": "hi",
            "previous_itinerary": None,
        },
    )
    assert response.status_code == 400
    data = response.json()
    assert data["error"] == "user_id required"


def test_chat_empty_user_id_returns_400():
    """POST /api/chat with empty user_id should return 400."""
    response = client.post(
        "/api/chat",
        json={
            "user_id": "",
            "message": "hi",
            "previous_itinerary": None,
        },
    )
    assert response.status_code == 400
    data = response.json()
    assert data["error"] == "user_id required"


def test_chat_missing_message_returns_400():
    """POST /api/chat without message should return 400."""
    response = client.post(
        "/api/chat",
        json={
            "user_id": "test-uuid-1234",
            "message": "",
            "previous_itinerary": None,
        },
    )
    assert response.status_code == 400
    data = response.json()
    assert data["error"] == "message required"


def test_chat_never_returns_500():
    """POST /api/chat should never return 500 — always 200 with error reply."""
    response = client.post(
        "/api/chat",
        json={
            "user_id": "test-uuid-nonexistent",
            "message": "Plan Saturday evening in Chennai",
            "previous_itinerary": None,
        },
    )
    # Should be 200 with error reply, not 500
    assert response.status_code == 200
    data = response.json()
    assert "reply" in data


def test_rate_missing_user_id_returns_400():
    """POST /api/rate without user_id should return 400."""
    response = client.post(
        "/api/rate",
        json={
            "user_id": "",
            "stop_id": "some-stop",
            "rating": "liked",
        },
    )
    assert response.status_code == 400


def test_profile_not_found():
    """GET /api/profile/{user_id} for a nonexistent user should return 404."""
    response = client.get("/api/profile/00000000-0000-0000-0000-000000000000")
    assert response.status_code == 404
