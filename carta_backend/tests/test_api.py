"""Tests for the FastAPI endpoints."""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_endpoint():
    """Health check should return 200 with status ok."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "carta-backend"


def test_chat_without_profile_returns_404():
    """POST /api/chat with a nonexistent user_id should return 404."""
    response = client.post(
        "/api/chat",
        json={
            "user_id": "00000000-0000-0000-0000-000000000000",
            "message": "Plan my Saturday evening",
        },
    )
    assert response.status_code == 404


def test_profile_not_found():
    """GET /api/profile/{user_id} for a nonexistent user should return 404."""
    response = client.get("/api/profile/00000000-0000-0000-0000-000000000000")
    assert response.status_code == 404


def test_rate_without_profile_returns_404():
    """POST /api/rate with a nonexistent user_id should return 404."""
    response = client.post(
        "/api/rate",
        json={
            "user_id": "00000000-0000-0000-0000-000000000000",
            "stop_id": "00000000-0000-0000-0000-000000000001",
            "rating": "liked",
        },
    )
    assert response.status_code == 404
