"""
backend/services/tts_service.py

Text-to-speech service abstraction.

In mock mode (USE_MOCK_SERVICES=true) this returns an explicit empty-audio
placeholder clearly marked as mock — it does NOT pretend to synthesise speech.

Real TTS provider adapters (GhanaNLP, Google TTS, etc.) should be implemented
here and selected via environment configuration.
"""
import os
from typing import Any, Dict

import logging

logger = logging.getLogger(__name__)

USE_MOCK: bool = os.getenv("USE_MOCK_SERVICES", "true").lower() in ("1", "true", "yes")

GHANANLP_API_KEY: str = os.getenv("GHANANLP_API_KEY", "")
GHANANLP_BASE_URL: str = os.getenv(
    "GHANANLP_BASE_URL", "https://translation-api.ghananlp.org"
)


class TTSService:
    """
    Text-to-speech service.

    When mocked: returns a clearly-labelled empty payload.
    When real: calls GhanaNLP TTS (requires GHANANLP_API_KEY).
    """

    def __init__(self) -> None:
        self.use_mock = USE_MOCK
        if not self.use_mock and not GHANANLP_API_KEY:
            logger.warning(
                "TTSService: USE_MOCK_SERVICES=false but GHANANLP_API_KEY is not set. "
                "TTS synthesis will fail for non-mock calls."
            )

    def synthesize(self, text: str, language: str = "en-GH") -> Dict[str, Any]:
        """
        Synthesise speech for the given text and language.

        Returns a dict with:
          mock        (bool)  — True when this is a development placeholder
          audio_bytes (bytes) — raw audio bytes (empty when mock)
          mime_type   (str)   — MIME type, e.g. 'audio/mpeg'
          url         (str|None)
          text        (str)   — the input text (for transparency)
        """
        if self.use_mock:
            # Development placeholder — explicitly labeled, returns no audio.
            # The Flutter app handles empty audio gracefully (no playback).
            logger.debug("TTSService: mock synthesis for language=%s", language)
            return {
                "mock": True,
                "audio_bytes": b"",
                "mime_type": "audio/mpeg",
                "url": None,
                "text": text,
            }

        return self._call_ghananlp(text, language)

    # ── Real provider ─────────────────────────────────────────────────────────

    def _call_ghananlp(self, text: str, language: str) -> Dict[str, Any]:
        """Call GhanaNLP TTS API."""
        import httpx  # noqa: PLC0415  lazy import — not needed in mock mode

        url = f"{GHANANLP_BASE_URL}/tts/v1/tts"
        headers = {
            "Content-Type": "application/json",
            "Ocp-Apim-Subscription-Key": GHANANLP_API_KEY,
        }
        payload = {"text": text, "language": language}

        try:
            with httpx.Client(timeout=60.0) as client:
                response = client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            return {
                "mock": False,
                "audio_bytes": response.content,
                "mime_type": "audio/mpeg",
                "url": None,
                "text": text,
            }
        except Exception as exc:
            logger.exception("GhanaNLP TTS failed: %s", exc)
            # Return silent placeholder rather than crashing the chat response.
            return {
                "mock": False,
                "audio_bytes": b"",
                "mime_type": "audio/mpeg",
                "url": None,
                "text": text,
            }
