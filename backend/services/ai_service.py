"""
backend/services/ai_service.py

A lightweight AI service abstraction that:
- Uses OpenAI when OPENAI_API_KEY is configured.
- Returns a structured JSON describing intent/entities/tool suggestions.
- Falls back to a provided fallback engine when OpenAI is not available or returns an unsafe result.

This service intentionally avoids fabricating factual data: when the model signals a tool is required
for factual information, the service will surface that requirement instead of inventing values.
"""
from __future__ import annotations

import json
import os
import logging
from typing import Any, Dict, Optional

try:
    import openai
except Exception:  # pragma: no cover - openai optional
    openai = None

logger = logging.getLogger(__name__)

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

# Basic system prompt to constrain the model output to JSON and avoid fabrication.
SYSTEM_PROMPT = (
    "You are Kofi, a helpful agricultural assistant for Ghanaian farmers. "
    "When asked to provide factual data (market prices, buyers, transport costs, weather, order details), "
    "DO NOT INVENT any values. Instead, return a JSON blob indicating the required tool to fetch the data.\n"
    "Always output a single valid JSON object and nothing else. The JSON MUST have the keys: "
    "intent (string), confidence (0..1), entities (object), tool (string|null), tool_args (object|null), "
    "requires_confirmation (boolean), response_text (string).\n"
    "If you are unable to determine an intent, set intent to 'general_chat' and response_text to a short clarifying question."
)


class AiService:
    def __init__(self, fallback_engine: Any = None, timeout: int = 20):
        self.fallback = fallback_engine
        self.timeout = timeout

        if OPENAI_API_KEY and openai:
            openai.api_key = OPENAI_API_KEY

    def _call_openai(self, message: str, language: str) -> Optional[Dict[str, Any]]:
        if not OPENAI_API_KEY or not openai:
            return None

        try:
            user_prompt = (
                f"Language: {language}\nUser: {message}\n\nRespond in JSON as specified."
            )

            resp = openai.ChatCompletion.create(
                model=OPENAI_MODEL,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt},
                ],
                temperature=0.0,
                max_tokens=512,
            )

            text = resp.choices[0].message.content.strip()

            # Attempt to parse JSON from the model output.
            try:
                parsed = json.loads(text)
                return parsed
            except Exception as e:
                logger.warning("OpenAI returned non-JSON or unparsable content: %s", e)
                return None

        except Exception as e:
            logger.exception("OpenAI call failed: %s", e)
            return None

    def process(
        self,
        message: str,
        language: str,
        conversation_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Return a structured assistant response.

        If OpenAI is available, ask it to provide a structured JSON response.
        If not, or if the model fails, fall back to the fallback engine (KofiEngine) which
        produces a safe textual response.
        """
        # Try OpenAI first
        result = self._call_openai(message=message, language=language)

        if result:
            # Ensure keys exist and coerce types to expected shapes.
            intent = str(result.get("intent", "general_chat"))
            confidence = float(result.get("confidence", 0.0))
            entities = result.get("entities") or {}
            tool = result.get("tool")
            tool_args = result.get("tool_args") or {}
            requires_confirmation = bool(result.get("requires_confirmation", False))
            response_text = str(result.get("response_text", "")).strip()

            return {
                "type": "response",
                "conversation_id": conversation_id or "",
                "message": response_text,
                "language": language,
                "detected_intent": intent,
                "intent_confidence": confidence,
                "entities": entities,
                "tool_used": tool,
                "tool_args": tool_args,
                "tool_result": None,
                "requires_confirmation": requires_confirmation,
                "pending_action": None,
                "actions": [],
                "navigation": None,
                "suggested_actions": result.get("suggested_actions", []),
                "expires_at": None,
            }

        # Fallback: use fallback engine if provided
        if self.fallback:
            try:
                fallback_result = self.fallback.process(
                    message=message,
                    language=language,
                    conversation_id=conversation_id or "",
                )

                # Ensure consistent keys expected by the FastAPI response model
                return {
                    "type": fallback_result.get("type", "response"),
                    "conversation_id": fallback_result.get("conversation_id", conversation_id or ""),
                    "message": fallback_result.get("message", ""),
                    "language": fallback_result.get("language", language),
                    "detected_intent": fallback_result.get("detected_intent"),
                    "intent_confidence": 0.0,
                    "entities": fallback_result.get("entities"),
                    "tool_used": fallback_result.get("tool_used"),
                    "tool_args": None,
                    "tool_result": None,
                    "requires_confirmation": fallback_result.get("requires_confirmation", False),
                    "pending_action": fallback_result.get("pending_action"),
                    "actions": fallback_result.get("actions", []),
                    "navigation": fallback_result.get("navigation"),
                    "suggested_actions": fallback_result.get("suggested_actions", []),
                    "expires_at": None,
                }
            except Exception as e:
                logger.exception("Fallback engine failed: %s", e)

        # Last resort: return a safe default message
        return {
            "type": "response",
            "conversation_id": conversation_id or "",
            "message": "I'm sorry — I couldn't process that right now.",
            "language": language,
            "detected_intent": "general_chat",
            "intent_confidence": 0.0,
            "entities": {},
            "tool_used": None,
            "tool_args": None,
            "tool_result": None,
            "requires_confirmation": False,
            "pending_action": None,
            "actions": [],
            "navigation": None,
            "suggested_actions": [],
            "expires_at": None,
        }
