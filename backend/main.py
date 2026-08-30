"""
backend/main.py

GeoHarvest Kofi AI — FastAPI backend.

Architecture:
    Flutter client
        ↓ HTTPS
    FastAPI (this file)
        ↓
    AiService (OpenAI / KofiEngine fallback)
        ↓
    ToolRegistry (market, buyers, transport, weather, orders)
        ↓
    TTSService (GhanaNLP TTS / mock)

Environment variables:
    OPENAI_API_KEY          — OpenAI key (optional; enables LLM mode)
    OPENAI_MODEL            — model name (default: gpt-4o-mini)
    GHANANLP_API_KEY        — GhanaNLP key for ASR + TTS
    GHANANLP_BASE_URL       — GhanaNLP base URL
    USE_MOCK_SERVICES       — 'true' to use mock tool/TTS responses (default: true)
    CORS_ORIGINS            — comma-separated list of allowed origins
                              (default: development-only localhost values)
    DATABASE_URL            — PostgreSQL URL (optional; in-memory fallback if unset)
    JWT_SECRET              — JWT signing secret (required in production)
    APP_ENV                 — 'development' | 'staging' | 'production'
"""
import base64
import os
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from backend.services.ai_service import AiService
from backend.services.tts_service import TTSService
from backend.tools.tool_registry import ToolRegistry
from backend.db import get_db_config

# ── Application metadata ─────────────────────────────────────────────────────

APP_NAME = "GeoHarvest AI API"
APP_VERSION = "3.0.0"

# ── Environment ───────────────────────────────────────────────────────────────

APP_ENV: str = os.getenv("APP_ENV", "development")
USE_MOCK: bool = os.getenv("USE_MOCK_SERVICES", "true").lower() in ("1", "true", "yes")

GHANANLP_BASE_URL: str = os.getenv(
    "GHANANLP_BASE_URL", "https://translation-api.ghananlp.org"
)
GHANANLP_API_KEY: str = os.getenv("GHANANLP_API_KEY", "")

# ── CORS ──────────────────────────────────────────────────────────────────────
# In production, set CORS_ORIGINS to a comma-separated list of real origins.
# In development, localhost origins are allowed by default.

_DEFAULT_DEV_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:8080",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:8080",
    # Android emulator reaches the host at 10.0.2.2
    "http://10.0.2.2:3000",
    "http://10.0.2.2:8080",
]

_cors_env = os.getenv("CORS_ORIGINS", "")
if _cors_env:
    CORS_ORIGINS: List[str] = [o.strip() for o in _cors_env.split(",") if o.strip()]
elif APP_ENV == "production":
    # Production with no explicit CORS_ORIGINS: deny all cross-origin requests.
    CORS_ORIGINS = []
else:
    # Development: allow common local origins.
    CORS_ORIGINS = _DEFAULT_DEV_ORIGINS

# ── FastAPI application ───────────────────────────────────────────────────────

app = FastAPI(
    title=APP_NAME,
    version=APP_VERSION,
    description="Voice-first agricultural AI backend for GeoHarvest.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)

# ── Services ──────────────────────────────────────────────────────────────────

tool_registry = ToolRegistry(use_mocks=USE_MOCK)
tts_service = TTSService()


class KofiEngine:
    """
    Rule-based fallback engine for Kofi AI.

    Used when OpenAI is not configured or unavailable.

    IMPORTANT: This engine never invents factual data (prices, buyers,
    weather, orders). When real data is needed, it explicitly tells the user
    that the live service connection is pending.
    """

    def process(
        self,
        message: str,
        language: str,
        conversation_id: str,
    ) -> Dict[str, Any]:
        text = message.lower().strip()
        intent = self._detect_intent(text)

        handlers = {
            "greeting": self._greeting,
            "check_price": self._price_response,
            "find_buyer": self._buyer_response,
            "find_transport": self._transport_response,
            "check_weather": self._weather_response,
            "track_order": self._order_response,
            "help": self._help_response,
            "thanks": self._thanks_response,
        }

        response_fn = handlers.get(intent, self._default_response)
        response_text = response_fn(language)

        return {
            "type": "response",
            "conversation_id": conversation_id,
            "message": response_text,
            "language": language,
            "detected_intent": intent,
            "tool_used": None,
            "tool_result": None,
            "requires_confirmation": False,
            "pending_action": None,
            "actions": [],
            "navigation": None,
            "suggested_actions": self._suggestions(intent),
            "expires_at": None,
        }

    def _detect_intent(self, text: str) -> str:
        if any(w in text for w in ["hello", "hi", "hey", "akwaaba", "good morning", "good afternoon"]):
            return "greeting"
        if any(w in text for w in ["price", "prices", "how much", "cost", "bo", "sika"]):
            return "check_price"
        if any(w in text for w in ["buyer", "buyers", "sell", "selling", "market", "customer", "tɔ"]):
            return "find_buyer"
        if any(w in text for w in ["transport", "transporter", "truck", "vehicle", "delivery", "lorry"]):
            return "find_transport"
        if any(w in text for w in ["weather", "rain", "raining", "sun", "forecast", "nsuo"]):
            return "check_weather"
        if any(w in text for w in ["order", "track", "tracking"]):
            return "track_order"
        if any(w in text for w in ["help", "assist", "boa", "what can you do"]):
            return "help"
        if any(w in text for w in ["thank", "thanks", "meda", "medaase"]):
            return "thanks"
        return "general_chat"

    def _greeting(self, lang: str) -> str:
        if lang == "tw":
            return "Akwaaba! Me yɛ Kofi, wo GeoHarvest assistant. Mepɛ sɛ meboa wo. Ka asɛm no."
        return "Hello! I'm Kofi, your GeoHarvest assistant. I can help with farming, buyers, produce, transport and more."

    def _price_response(self, lang: str) -> str:
        if lang == "tw":
            return "Mɛtumi ahwehwɛ market prices. Nanso live market-price service no nnya nni hɔ bio. Ka crop ne market a wopɛ sɛ mecheck."
        return "I can check market prices when the GeoHarvest market-price service is connected. Tell me the crop and market."

    def _buyer_response(self, lang: str) -> str:
        if lang == "tw":
            return "Mɛtumi ahwehwɛ buyers. Live buyer service no da so reba. Ka produce, quantity ne wo location."
        return "I can help find buyers. The live buyer service is being connected. Tell me your produce, quantity and location."

    def _transport_response(self, lang: str) -> str:
        if lang == "tw":
            return "Mɛtumi ahwehwɛ transporter. Live transport service no da so reba. Ka wo location, produce ne quantity."
        return "I can help find transport. The live transport service is being connected. Tell me your location, produce and quantity."

    def _weather_response(self, lang: str) -> str:
        if lang == "tw":
            return "Mɛtumi akyerɛ wo weather forecast sɛ live weather service no connected."
        return "I can provide weather once the live GeoHarvest weather service is connected."

    def _order_response(self, lang: str) -> str:
        if lang == "tw":
            return "Ka wo order number no ma me sɛ live order service no connected."
        return "Give me your order number and I can check it when the live order service is connected."

    def _help_response(self, lang: str) -> str:
        if lang == "tw":
            return "Mɛboa wo wɔ produce, buyers, market prices, transport, weather ne orders ho. Ka nea wopɛ sɛ yɛyɛ."
        return "I can help with produce, buyers, market prices, transport, weather and orders."

    def _thanks_response(self, lang: str) -> str:
        if lang == "tw":
            return "Meda wo ase. Biribi foforo wɔ hɔ a wopɛ sɛ meboa wo?"
        return "You're welcome. What else can I help you with?"

    def _default_response(self, lang: str) -> str:
        if lang == "tw":
            return "Meate wo asɛm no. Ka ho asɛm kakra na mɛboa wo."
        return "I hear you. Tell me a little more about what you need and I'll help."

    def _suggestions(self, intent: str) -> List[str]:
        base = ["Check market price", "Find buyers", "Find transport"]
        return {
            "check_price": base,
            "find_buyer": ["Check market price", "Find transport"],
            "find_transport": ["Find buyers", "Track order"],
            "check_weather": ["Check market price", "Find buyers"],
        }.get(intent, base)


kofi_engine = KofiEngine()
ai_service = AiService(fallback_engine=kofi_engine)

# ── In-memory conversation store ─────────────────────────────────────────────
# DEVELOPMENT ONLY: lost on restart.
# TODO: replace with PostgreSQL-backed persistence (see backend/db/).

conversations: Dict[str, List[Dict[str, Any]]] = {}


def _get_or_create_conversation(conversation_id: Optional[str]) -> str:
    if conversation_id and conversation_id in conversations:
        return conversation_id
    new_id = str(uuid.uuid4())
    conversations[new_id] = []
    return new_id


def _save_message(cid: str, role: str, content: str, language: str) -> None:
    history = conversations.setdefault(cid, [])
    history.append({
        "role": role,
        "content": content,
        "language": language,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })
    # Keep last 30 messages to avoid unbounded growth
    if len(history) > 30:
        conversations[cid] = history[-30:]


def _history_for_ai(cid: str) -> List[Dict[str, str]]:
    """Return the last 10 messages formatted for OpenAI chat history."""
    return [
        {"role": m["role"], "content": m["content"]}
        for m in conversations.get(cid, [])[-10:]
    ]


# ── Language normalisation ────────────────────────────────────────────────────

SUPPORTED_LANGUAGES = {"tw", "en-GH", "gaa", "dag", "ee", "yo"}
_ALIASES = {
    "en": "en-GH", "english": "en-GH",
    "twi": "tw", "akan": "tw",
    "ga": "gaa",
    "ewe": "ee",
    "dagbani": "dag",
    "yoruba": "yo",
}


def _normalise_language(language: str) -> str:
    lang = (language or "en-GH").strip()
    if lang in SUPPORTED_LANGUAGES:
        return lang
    return _ALIASES.get(lang.lower(), "en-GH")


# ── Pydantic models ───────────────────────────────────────────────────────────

class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=5000)
    language: str = "en-GH"
    conversation_id: Optional[str] = None


class ChatResponse(BaseModel):
    type: str = "response"
    conversation_id: str
    message: str
    language: str
    detected_intent: Optional[str] = None
    intent_confidence: float = 0.0
    tool_used: Optional[str] = None
    tool_result: Optional[Dict[str, Any]] = None
    requires_confirmation: bool = False
    pending_action: Optional[Dict[str, Any]] = None
    actions: List[Any] = Field(default_factory=list)
    navigation: Optional[Dict[str, Any]] = None
    suggested_actions: List[Any] = Field(default_factory=list)
    expires_at: Optional[str] = None
    audio_base64: Optional[str] = None
    audio_mime: Optional[str] = None


class VoiceRequest(BaseModel):
    audio: str = Field(min_length=1)
    language: str = "tw"
    audio_format: str = "wav"


class VoiceResponse(BaseModel):
    transcript: str
    language: str
    ai: ChatResponse


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/")
def root() -> Dict[str, Any]:
    return {
        "name": APP_NAME,
        "version": APP_VERSION,
        "status": "running",
        "service": "GeoHarvest Kofi",
        "env": APP_ENV,
    }


@app.get("/health")
def health() -> Dict[str, Any]:
    return {
        "status": "ok",
        "service": APP_NAME,
        "version": APP_VERSION,
        "env": APP_ENV,
        "use_mock_services": USE_MOCK,
        "ghananlp_configured": bool(GHANANLP_API_KEY),
        "openai_configured": bool(os.getenv("OPENAI_API_KEY", "")),
        "database": get_db_config(),
    }


@app.post("/api/v1/ai/chat", response_model=ChatResponse)
def chat(request: ChatRequest) -> ChatResponse:
    language = _normalise_language(request.language)
    cid = _get_or_create_conversation(request.conversation_id)

    _save_message(cid, "user", request.message, language)

    result = ai_service.process(
        message=request.message,
        language=language,
        conversation_id=cid,
        history=_history_for_ai(cid),
    )
    result["conversation_id"] = cid

    _save_message(cid, "assistant", result.get("message", ""), language)

    # Attach TTS audio if available (non-mock only to avoid empty base64 noise)
    tts_result = tts_service.synthesize(
        text=result.get("message", ""),
        language=language,
    )
    if not tts_result["mock"] and tts_result["audio_bytes"]:
        result["audio_base64"] = base64.b64encode(tts_result["audio_bytes"]).decode()
        result["audio_mime"] = tts_result["mime_type"]
    else:
        result["audio_base64"] = None
        result["audio_mime"] = None

    return ChatResponse(**result)


@app.post("/api/v1/ai/voice", response_model=VoiceResponse)
async def voice(request: VoiceRequest) -> VoiceResponse:
    # Decode audio
    try:
        audio_bytes = base64.b64decode(request.audio, validate=True)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Invalid base64 audio: {exc}")

    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Audio payload is empty.")

    # ASR via GhanaNLP
    transcript = await _ghananlp_transcribe(
        audio_bytes=audio_bytes,
        language=request.language,
        audio_format=request.audio_format,
    )

    if not transcript:
        raise HTTPException(
            status_code=422,
            detail="Speech recognition returned an empty transcript.",
        )

    language = _normalise_language(request.language)
    cid = _get_or_create_conversation(None)

    _save_message(cid, "user", transcript, language)

    result = ai_service.process(
        message=transcript,
        language=language,
        conversation_id=cid,
        history=_history_for_ai(cid),
    )
    result["conversation_id"] = cid

    _save_message(cid, "assistant", result.get("message", ""), language)

    tts_result = tts_service.synthesize(
        text=result.get("message", ""),
        language=language,
    )
    if not tts_result["mock"] and tts_result["audio_bytes"]:
        result["audio_base64"] = base64.b64encode(tts_result["audio_bytes"]).decode()
        result["audio_mime"] = tts_result["mime_type"]
    else:
        result["audio_base64"] = None
        result["audio_mime"] = None

    return VoiceResponse(
        transcript=transcript,
        language=language,
        ai=ChatResponse(**result),
    )


@app.get("/api/v1/ai/conversations")
def list_conversations() -> Dict[str, Any]:
    return {
        "conversations": [
            {"id": cid, "messages": msgs[-10:]}
            for cid, msgs in conversations.items()
        ]
    }


@app.get("/api/v1/ai/conversations/{conversation_id}")
def get_conversation(conversation_id: str) -> Dict[str, Any]:
    if conversation_id not in conversations:
        raise HTTPException(status_code=404, detail="Conversation not found.")
    return {
        "id": conversation_id,
        "messages": conversations[conversation_id],
    }


# ── GhanaNLP ASR helper ───────────────────────────────────────────────────────

async def _ghananlp_transcribe(
    audio_bytes: bytes,
    language: str,
    audio_format: str,
) -> str:
    if not GHANANLP_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="GHANANLP_API_KEY is not configured on the backend.",
        )

    language = _normalise_language(language)

    content_types = {
        "wav": "audio/wav",
        "mp3": "audio/mpeg",
        "m4a": "audio/mp4",
        "aac": "audio/aac",
        "webm": "audio/webm",
    }
    content_type = content_types.get(audio_format.lower(), "audio/wav")

    url = f"{GHANANLP_BASE_URL}/asr/v2/transcribe?language={language}"
    headers = {
        "Content-Type": content_type,
        "Ocp-Apim-Subscription-Key": GHANANLP_API_KEY,
    }

    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(url, headers=headers, content=audio_bytes)

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"GhanaNLP ASR failed ({response.status_code}): {response.text[:500]}",
        )

    return response.text.strip()
