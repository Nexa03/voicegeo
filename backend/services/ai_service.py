"""
backend/services/ai_service.py

Kofi AI service — routes messages through OpenAI (or another LLM) when
configured, and falls back to KofiEngine for safe, rule-based responses.

Design principles:
- Never invent factual data (prices, buyers, weather, orders).
- When a tool is required for factual data, surface the requirement
  rather than fabricating a value.
- OpenAI integration uses the current client API (openai >= 1.0).
- KofiEngine is the fallback, not the primary intelligence.
"""
from __future__ import annotations

import json
import logging
import os
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL: str = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

# ── System prompt ─────────────────────────────────────────────────────────────

_SYSTEM_PROMPT = """\
You are Kofi, an agricultural AI assistant for Ghanaian farmers using the
GeoHarvest platform. You help farmers with:
- Crop information and farming advice
- Navigating the GeoHarvest marketplace
- Finding buyers for their produce
- Locating transport providers
- Understanding market prices
- Weather and logistics planning

CRITICAL RULE — Never invent factual data:
When the user asks for market prices, buyer details, transport costs, weather
conditions, or order status, DO NOT fabricate values. Instead, respond with a
JSON object indicating the tool required to fetch the real data.

Always respond with a single valid JSON object with these keys:
  intent         (string)  — detected user intent
  confidence     (float)   — 0.0 to 1.0
  entities       (object)  — extracted named entities
  tool           (string|null) — tool name if real data is needed
  tool_args      (object|null) — arguments for the tool
  requires_confirmation (boolean) — whether to confirm before executing
  response_text  (string)  — natural language response to the user

Supported languages: Twi (tw), Ghanaian English (en-GH), Ga (gaa),
Dagbani (dag), Ewe (ee), Yoruba (yo).
When the user writes in a Ghanaian language, respond in that language.
"""


class AiService:
    """
    AI service that wraps OpenAI with KofiEngine fallback.

    Usage:
        service = AiService(fallback_engine=kofi_engine_instance)
        result = service.process(message="...", language="en-GH",
                                 conversation_id="...",
                                 history=[...])
    """

    def __init__(
        self,
        fallback_engine: Any = None,
        timeout: int = 20,
    ) -> None:
        self.fallback = fallback_engine
        self.timeout = timeout
        self._client: Any = None

        if OPENAI_API_KEY:
            try:
                from openai import OpenAI  # openai >= 1.0  # noqa: PLC0415
                self._client = OpenAI(
                    api_key=OPENAI_API_KEY,
                    timeout=float(timeout),
                )
                logger.info("AiService: OpenAI client initialised (model=%s)", OPENAI_MODEL)
            except ImportError:
                logger.warning("AiService: openai package not available; using fallback only")
            except Exception as exc:  # pragma: no cover
                logger.warning("AiService: OpenAI init failed: %s", exc)
        else:
            logger.info("AiService: OPENAI_API_KEY not set; using fallback only")

    # ── Public API ────────────────────────────────────────────────────────────

    def process(
        self,
        message: str,
        language: str,
        conversation_id: Optional[str] = None,
        history: Optional[List[Dict[str, str]]] = None,
    ) -> Dict[str, Any]:
        """
        Process a user message and return a structured response dict.

        Tries OpenAI first; falls back to KofiEngine if unavailable or on
        parse failure.
        """
        result = self._call_openai(message, language, history or [])
        if result:
            return self._build_response(result, language, conversation_id)

        if self.fallback:
            try:
                fb = self.fallback.process(
                    message=message,
                    language=language,
                    conversation_id=conversation_id or "",
                )
                return self._normalise_fallback(fb, language, conversation_id)
            except Exception as exc:
                logger.exception("Fallback engine failed: %s", exc)

        return self._safe_default(language, conversation_id)

    # ── OpenAI call ───────────────────────────────────────────────────────────

    def _call_openai(
        self,
        message: str,
        language: str,
        history: List[Dict[str, str]],
    ) -> Optional[Dict[str, Any]]:
        if not self._client:
            return None

        try:
            messages: List[Dict[str, str]] = [
                {"role": "system", "content": _SYSTEM_PROMPT},
            ]
            # Include recent history for context (last 10 turns)
            messages.extend(history[-10:])
            messages.append({
                "role": "user",
                "content": f"Language: {language}\nMessage: {message}\n\nRespond in JSON.",
            })

            response = self._client.chat.completions.create(
                model=OPENAI_MODEL,
                messages=messages,
                temperature=0.0,
                max_tokens=512,
            )

            text = response.choices[0].message.content or ""
            text = text.strip()

            # Strip markdown code fences if present
            if text.startswith("```"):
                lines = text.splitlines()
                text = "\n".join(
                    line for line in lines
                    if not line.strip().startswith("```")
                )

            parsed: Dict[str, Any] = json.loads(text)
            return parsed

        except json.JSONDecodeError as exc:
            logger.warning("OpenAI returned non-JSON: %s", exc)
            return None
        except Exception as exc:
            logger.exception("OpenAI call failed: %s", exc)
            return None

    # ── Response builders ─────────────────────────────────────────────────────

    def _build_response(
        self,
        parsed: Dict[str, Any],
        language: str,
        conversation_id: Optional[str],
    ) -> Dict[str, Any]:
        return {
            "type": "response",
            "conversation_id": conversation_id or "",
            "message": str(parsed.get("response_text", "")).strip(),
            "language": language,
            "detected_intent": str(parsed.get("intent", "general_chat")),
            "intent_confidence": float(parsed.get("confidence", 0.0)),
            "entities": parsed.get("entities") or {},
            "tool_used": parsed.get("tool"),
            "tool_args": parsed.get("tool_args") or {},
            "tool_result": None,
            "requires_confirmation": bool(parsed.get("requires_confirmation", False)),
            "pending_action": None,
            "actions": [],
            "navigation": None,
            "suggested_actions": list(parsed.get("suggested_actions", [])),
            "expires_at": None,
        }

    def _normalise_fallback(
        self,
        fb: Dict[str, Any],
        language: str,
        conversation_id: Optional[str],
    ) -> Dict[str, Any]:
        return {
            "type": fb.get("type", "response"),
            "conversation_id": fb.get("conversation_id") or conversation_id or "",
            "message": fb.get("message", ""),
            "language": fb.get("language", language),
            "detected_intent": fb.get("detected_intent"),
            "intent_confidence": 0.0,
            "entities": fb.get("entities") or {},
            "tool_used": fb.get("tool_used"),
            "tool_args": None,
            "tool_result": None,
            "requires_confirmation": fb.get("requires_confirmation", False),
            "pending_action": fb.get("pending_action"),
            "actions": fb.get("actions", []),
            "navigation": fb.get("navigation"),
            "suggested_actions": fb.get("suggested_actions", []),
            "expires_at": None,
        }

    def _safe_default(
        self,
        language: str,
        conversation_id: Optional[str],
    ) -> Dict[str, Any]:
        if language == "tw":
            msg = "Meboa wo. Ka ho asɛm kakra ma me."
        else:
            msg = "I am here to help. Could you tell me a little more?"

        return {
            "type": "response",
            "conversation_id": conversation_id or "",
            "message": msg,
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
