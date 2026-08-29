"""
backend/services/tts_service.py

Simple TTS service abstraction. In mock mode this returns an empty audio payload
with a flag marking it as mock. Real providers should be implemented later and
registered via configuration.
"""
from typing import Dict, Any
import os

USE_MOCK = os.getenv("USE_MOCK_SERVICES", "true").lower() in ("1", "true", "yes")


class TTSService:
    def __init__(self):
        self.use_mocks = USE_MOCK

    def synthesize(self, text: str, language: str = "en-GH") -> Dict[str, Any]:
        if self.use_mocks:
            # Return an explicit mock response. No real audio is produced to avoid
            # shipping vendor credentials or heavy binaries in repo.
            return {
                "mock": True,
                "audio_bytes": b"",
                "mime_type": "audio/mpeg",
                "url": None,
                "text": text,
            }

        # Placeholder for real implementation
        return {"mock": False, "audio_bytes": b"", "mime_type": "audio/mpeg", "url": None, "text": text}
