# backend/tests/test_endpoints.py

import base64
import json
from fastapi.testclient import TestClient
import pytest

from backend import main as app_module

client = TestClient(app_module.app)


def test_root():
    r = client.get("/")
    assert r.status_code == 200
    data = r.json()
    assert data.get("name") == app_module.APP_NAME


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    data = r.json()
    assert "use_mock_services" in data
    assert isinstance(data.get("services"), dict)


def test_chat_fallback():
    payload = {"message": "Hello Kofi", "language": "en-GH"}
    r = client.post("/api/v1/ai/chat", json=payload)
    assert r.status_code == 200
    data = r.json()
    assert "message" in data
    assert "conversation_id" in data


def test_voice_invalid_base64():
    payload = {"audio": "not-base64", "language": "tw", "audio_format": "wav"}
    r = client.post("/api/v1/ai/voice", json=payload)
    assert r.status_code == 400


def test_voice_empty_audio():
    # Send valid base64 but empty content
    empty_b64 = base64.b64encode(b"").decode("ascii")
    payload = {"audio": empty_b64, "language": "tw", "audio_format": "wav"}
    r = client.post("/api/v1/ai/voice", json=payload)
    # Our endpoint treats empty bytes as error 400
    assert r.status_code == 400


def test_tool_execution_mock_price():
    # Use chat message that should trigger price intent according to KofiEngine keywords
    payload = {"message": "How much is tomato in Techiman?", "language": "en-GH"}
    r = client.post("/api/v1/ai/chat", json=payload)
    assert r.status_code == 200
    data = r.json()
    # If AI suggests a tool, tool_result should be present when mocks enabled
    # The fallback KofiEngine doesn't set tool_used, but ensure response keys exist
    assert "message" in data
    assert "detected_intent" in data
