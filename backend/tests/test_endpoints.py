"""
backend/tests/test_endpoints.py

Integration tests for the GeoHarvest FastAPI backend.

All tests use the FastAPI TestClient (in-process, no real network).
Tests do NOT require a running server, database, or external API keys.
"""
import base64
import os

import pytest
from fastapi.testclient import TestClient

# Ensure mock mode is active for tests regardless of host environment
os.environ.setdefault("USE_MOCK_SERVICES", "true")
os.environ.setdefault("APP_ENV", "development")

from backend.main import APP_NAME, APP_VERSION, app  # noqa: E402

client = TestClient(app)


# ── Root and health ───────────────────────────────────────────────────────────

def test_root():
    r = client.get("/")
    assert r.status_code == 200
    data = r.json()
    assert data["name"] == APP_NAME
    assert data["version"] == APP_VERSION
    assert data["status"] == "running"


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert data["status"] == "ok"
    assert "use_mock_services" in data
    assert isinstance(data["use_mock_services"], bool)
    assert "ghananlp_configured" in data
    assert "openai_configured" in data
    assert "database" in data


# ── Chat endpoint ─────────────────────────────────────────────────────────────

def test_chat_english():
    r = client.post(
        "/api/v1/ai/chat",
        json={"message": "Hello Kofi", "language": "en-GH"},
    )
    assert r.status_code == 200
    data = r.json()
    assert "message" in data
    assert "conversation_id" in data
    assert data["message"]  # non-empty response


def test_chat_twi():
    r = client.post(
        "/api/v1/ai/chat",
        json={"message": "Akwaaba", "language": "tw"},
    )
    assert r.status_code == 200
    data = r.json()
    assert "message" in data
    assert data["language"] == "tw"


def test_chat_conversation_continues():
    """Second message re-uses the conversation_id from the first."""
    r1 = client.post(
        "/api/v1/ai/chat",
        json={"message": "Hello", "language": "en-GH"},
    )
    assert r1.status_code == 200
    cid = r1.json()["conversation_id"]
    assert cid

    r2 = client.post(
        "/api/v1/ai/chat",
        json={"message": "What can you do?", "language": "en-GH", "conversation_id": cid},
    )
    assert r2.status_code == 200
    assert r2.json()["conversation_id"] == cid


def test_chat_price_intent():
    r = client.post(
        "/api/v1/ai/chat",
        json={"message": "How much is tomato in Techiman?", "language": "en-GH"},
    )
    assert r.status_code == 200
    data = r.json()
    assert "message" in data
    assert data["message"]


def test_chat_invalid_message_too_short():
    r = client.post(
        "/api/v1/ai/chat",
        json={"message": "", "language": "en-GH"},
    )
    assert r.status_code == 422


def test_chat_unknown_language_defaults_to_en_gh():
    r = client.post(
        "/api/v1/ai/chat",
        json={"message": "Hello", "language": "xyz-unknown"},
    )
    assert r.status_code == 200
    assert r.json()["language"] == "en-GH"


# ── Voice endpoint ────────────────────────────────────────────────────────────

def test_voice_invalid_base64():
    r = client.post(
        "/api/v1/ai/voice",
        json={"audio": "not-valid-base64!!!", "language": "tw", "audio_format": "wav"},
    )
    assert r.status_code == 400


def test_voice_empty_audio():
    empty_b64 = base64.b64encode(b"").decode()
    r = client.post(
        "/api/v1/ai/voice",
        json={"audio": empty_b64, "language": "tw", "audio_format": "wav"},
    )
    assert r.status_code == 400


# ── Conversation store ────────────────────────────────────────────────────────

def test_get_conversations():
    # First create a conversation
    client.post(
        "/api/v1/ai/chat",
        json={"message": "Test message", "language": "en-GH"},
    )
    r = client.get("/api/v1/ai/conversations")
    assert r.status_code == 200
    assert "conversations" in r.json()


def test_get_conversation_not_found():
    r = client.get("/api/v1/ai/conversations/does-not-exist-00000")
    assert r.status_code == 404


# ── Tool registry (unit-level) ────────────────────────────────────────────────

def test_tool_registry_mock_price():
    from backend.tools.tool_registry import ToolRegistry
    registry = ToolRegistry(use_mocks=True)
    result = registry.execute("check_market_price", {"crop": "tomato", "market": "Techiman"})
    assert result["mock"] is True
    assert "price" in result
    assert result["crop"] == "tomato"


def test_tool_registry_mock_buyers():
    from backend.tools.tool_registry import ToolRegistry
    registry = ToolRegistry(use_mocks=True)
    result = registry.execute("find_buyers", {"produce": "yam", "quantity": 500, "location": "Kumasi"})
    assert result["mock"] is True
    assert "buyers" in result
    assert isinstance(result["buyers"], list)


def test_tool_registry_mock_weather():
    from backend.tools.tool_registry import ToolRegistry
    registry = ToolRegistry(use_mocks=True)
    result = registry.execute("get_weather", {"location": "Tamale"})
    assert result["mock"] is True
    assert "forecast" in result


def test_tool_registry_unknown_tool():
    from backend.tools.tool_registry import ToolRegistry
    registry = ToolRegistry(use_mocks=True)
    result = registry.execute("nonexistent_tool", {})
    assert result["available"] is False
    assert result["error_code"] == "UNKNOWN_TOOL"


def test_tool_registry_missing_argument():
    from backend.tools.tool_registry import ToolRegistry
    registry = ToolRegistry(use_mocks=True)
    result = registry.execute("check_market_price", {"crop": "tomato"})  # missing 'market'
    assert result["available"] is False
    assert result["error_code"] == "MISSING_ARGUMENT"


# ── AI service (unit-level) ───────────────────────────────────────────────────

def test_ai_service_fallback_without_openai():
    """AiService must return a valid response when OpenAI is not configured."""
    import importlib
    import backend.services.ai_service as ai_mod

    # Ensure no key is set for this test
    original_key = ai_mod.OPENAI_API_KEY
    ai_mod.OPENAI_API_KEY = ""

    from backend.main import kofi_engine
    service = ai_mod.AiService(fallback_engine=kofi_engine)
    result = service.process(message="Hello", language="en-GH", conversation_id="test-cid")

    ai_mod.OPENAI_API_KEY = original_key

    assert "message" in result
    assert result["message"]
    assert result["language"] == "en-GH"
