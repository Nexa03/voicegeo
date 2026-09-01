import base64
import os
import uuid
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from openai import OpenAI, APIError, APIConnectionError, APITimeoutError


# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

APP_NAME = "GeoHarvest AI API"
APP_VERSION = "2.0.0"

GHANANLP_BASE_URL = os.getenv(
    "GHANANLP_BASE_URL",
    "https://translation-api.ghananlp.org",
)
GHANANLP_API_KEY = os.getenv("GHANANLP_API_KEY", "")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
OPENAI_TIMEOUT = 10.0  # seconds

# Initialize OpenAI client if API key is set
openai_client = None
if OPENAI_API_KEY:
    try:
        openai_client = OpenAI(api_key=OPENAI_API_KEY)
    except Exception as e:
        logger.warning(f"Failed to initialize OpenAI client: {e}")


app = FastAPI(
    title=APP_NAME,
    version=APP_VERSION,
    description="Voice-first agricultural AI backend for GeoHarvest.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


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
    tool_used: Optional[str] = None
    tool_result: Optional[Dict[str, Any]] = None
    requires_confirmation: bool = False
    pending_action: Optional[Dict[str, Any]] = None
    actions: List[Any] = Field(default_factory=list)
    navigation: Optional[Dict[str, Any]] = None
    suggested_actions: List[Any] = Field(default_factory=list)
    expires_at: Optional[str] = None


class VoiceRequest(BaseModel):
    audio: str = Field(min_length=1)
    language: str = "tw"
    audio_format: str = "wav"


class VoiceResponse(BaseModel):
    transcript: str
    language: str
    ai: ChatResponse


conversations: Dict[str, List[Dict[str, Any]]] = {}


def get_or_create_conversation(conversation_id: Optional[str]) -> str:
    if conversation_id and conversation_id in conversations:
        return conversation_id

    new_id = str(uuid.uuid4())
    conversations[new_id] = []
    return new_id


def save_message(
    conversation_id: str,
    role: str,
    content: str,
    language: str,
) -> None:
    history = conversations.setdefault(conversation_id, [])

    history.append(
        {
            "role": role,
            "content": content,
            "language": language,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    )

    if len(history) > 30:
        conversations[conversation_id] = history[-30:]


SUPPORTED_LANGUAGES = {
    "tw",
    "en-GH",
    "gaa",
    "dag",
    "ee",
    "yo",
}


def normalize_language(language: str) -> str:
    language = (language or "en-GH").strip()

    if language in SUPPORTED_LANGUAGES:
        return language

    aliases = {
        "en": "en-GH",
        "english": "en-GH",
        "twi": "tw",
        "akan": "tw",
        "gaa": "gaa",
        "ga": "gaa",
        "ewe": "ee",
        "dagbani": "dag",
        "yoruba": "yo",
    }

    return aliases.get(language.lower(), "en-GH")


SYSTEM_PROMPT = """You are Kofi, a helpful agricultural assistant for Ghanaian farmers.
You provide advice about farming, buyers, produce, market prices, transport, and weather.

CRITICAL: Do NOT invent or hallucinate data. Only provide information you are certain about.
- Do NOT make up market prices, buyer contacts, or transporter details.
- Do NOT fabricate weather forecasts or crop data.
- If you don't have specific data, ask the user for more details or suggest they contact a specialist.
- Keep responses concise and practical.
"""


class KofiEngine:
    """
    Safe fallback engine.

    IMPORTANT:
    This engine deliberately does NOT invent market prices,
    buyer counts, transporter costs or weather conditions.

    Those values must come from real GeoHarvest services later.
    """

    def process(
        self,
        message: str,
        language: str,
        conversation_id: str,
    ) -> Dict[str, Any]:

        text = message.lower().strip()

        intent = self.detect_intent(text)

        if intent == "greeting":
            response = self.greeting(language)

        elif intent == "check_price":
            response = self.price_response(language)

        elif intent == "find_buyer":
            response = self.buyer_response(language)

        elif intent == "find_transport":
            response = self.transport_response(language)

        elif intent == "check_weather":
            response = self.weather_response(language)

        elif intent == "track_order":
            response = self.order_response(language)

        elif intent == "help":
            response = self.help_response(language)

        elif intent == "thanks":
            response = self.thanks_response(language)

        else:
            response = self.default_response(language)

        return {
            "type": "response",
            "conversation_id": conversation_id,
            "message": response,
            "language": language,
            "detected_intent": intent,
            "tool_used": None,
            "tool_result": None,
            "requires_confirmation": False,
            "pending_action": None,
            "actions": [],
            "navigation": None,
            "suggested_actions": self.suggestions(intent),
            "expires_at": None,
        }

    def detect_intent(self, text: str) -> str:
        if any(
            word in text
            for word in [
                "hello",
                "hi",
                "hey",
                "akwaaba",
                "good morning",
                "good afternoon",
            ]
        ):
            return "greeting"

        if any(
            word in text
            for word in [
                "price",
                "prices",
                "how much",
                "cost",
                "bo",
                "sika",
                "ɛyɛ",
            ]
        ):
            return "check_price"

        if any(
            word in text
            for word in [
                "buyer",
                "buyers",
                "sell",
                "selling",
                "market",
                "customer",
                "tɔ",
                "tɔn",
            ]
        ):
            return "find_buyer"

        if any(
            word in text
            for word in [
                "transport",
                "transporter",
                "truck",
                "vehicle",
                "delivery",
                "lorry",
                "car",
            ]
        ):
            return "find_transport"

        if any(
            word in text
            for word in [
                "weather",
                "rain",
                "raining",
                "sun",
                "forecast",
                "nsuo",
            ]
        ):
            return "check_weather"

        if any(
            word in text
            for word in [
                "order",
                "track",
                "tracking",
                "delivery status",
            ]
        ):
            return "track_order"

        if any(
            word in text
            for word in [
                "help",
                "assist",
                "boa",
                "what can you do",
            ]
        ):
            return "help"

        if any(
            word in text
            for word in [
                "thank",
                "thanks",
                "meda",
                "medaase",
            ]
        ):
            return "thanks"

        return "general_chat"

    def greeting(self, language: str) -> str:
        if language == "tw":
            return (
                "Akwaaba! Me yɛ Kofi, wo GeoHarvest assistant. "
                "Mepɛ sɛ meboa wo. Ka asɛm no."
            )

        return (
            "Hello! I'm Kofi, your GeoHarvest assistant. "
            "I can help you with farming, buyers, produce, transport "
            "and other GeoHarvest services."
        )

    def price_response(self, language: str) -> str:
        if language == "tw":
            return (
                "Mɛtumi ahwehwɛ nnɛ deɛ ɛyɛ nokware wɔ market prices mu. "
                "Nanso saa bere yi, market-price service no nnya nni hɔ. "
                "Ka crop ne market a wopɛ sɛ mecheck."
            )

        return (
            "I can check market prices when the GeoHarvest market-price "
            "service is connected. I won't invent a price for you. "
            "Tell me the crop and market you want to check."
        )

    def buyer_response(self, language: str) -> str:
        if language == "tw":
            return (
                "Mɛtumi ahwehwɛ buyers ama wo. "
                "Merehwehwɛ buyer service no connection. "
                "Ka produce, quantity ne wo location."
            )

        return (
            "I can help you find buyers. The live buyer service still "
            "needs to be connected. Tell me your produce, quantity and location."
        )

    def transport_response(self, language: str) -> str:
        if language == "tw":
            return (
                "Mɛtumi ahwehwɛ transporter ama wo. "
                "Live transport matching service no da so reba. "
                "Ka wo location, produce ne quantity."
            )

        return (
            "I can help find transport. The live transporter-matching "
            "service still needs to be connected. Tell me your location, "
            "produce and quantity."
        )

    def weather_response(self, language: str) -> str:
        if language == "tw":
            return (
                "Mɛtumi akyerɛ wo weather forecast, nanso ɛsɛ sɛ meconnect "
                "me live weather service ansa na matumi ama wo forecast a ɛyɛ nokware."
            )

        return (
            "I can provide weather information once the live GeoHarvest "
            "weather service is connected. I won't make up a forecast."
        )

    def order_response(self, language: str) -> str:
        if language == "tw":
            return (
                "Ka wo order number no ma me, na mɛhwɛ tracking information "
                "sɛ live order service no connected."
            )

        return (
            "Give me your order or tracking number and I can check it "
            "when the live GeoHarvest order service is connected."
        )

    def help_response(self, language: str) -> str:
        if language == "tw":
            return (
                "Mɛboa wo wɔ produce, buyers, market prices, transport, "
                "weather ne orders ho. Ka nea wopɛ sɛ yɛyɛ."
            )

        return (
            "I can help with produce, buyers, market prices, transport, "
            "weather and orders. Tell me what you want to do."
        )

    def thanks_response(self, language: str) -> str:
        if language == "tw":
            return "Meda wo ase. Biribi foforo wɔ hɔ a wopɛ sɛ meboa wo?"

        return "You're welcome. What else can I help you with?"

    def default_response(self, language: str) -> str:
        if language == "tw":
            return (
                "Meate wo asɛm no. Ka ho asɛm kakra na mɛboa wo."
            )

        return (
            "I hear you. Tell me a little more about what you need "
            "and I'll help."
        )

    def suggestions(self, intent: str) -> List[str]:
        suggestions = {
            "check_price": [
                "Check tomato price",
                "Find buyers",
                "Find transport",
            ],
            "find_buyer": [
                "Check market price",
                "Find transport",
            ],
            "find_transport": [
                "Find buyers",
                "Track order",
            ],
            "check_weather": [
                "Check market price",
                "Find buyers",
            ],
        }

        return suggestions.get(
            intent,
            [
                "Check market price",
                "Find buyers",
                "Find transport",
            ],
        )


kofi = KofiEngine()


async def ghananlp_transcribe(
    audio_bytes: bytes,
    language: str,
    audio_format: str,
) -> str:

    if not GHANANLP_API_KEY:
        raise HTTPException(
            status_code=503,
            detail=(
                "GHANANLP_API_KEY is not configured on the backend."
            ),
        )

    language = normalize_language(language)

    content_types = {
        "wav": "audio/wav",
        "mp3": "audio/mpeg",
        "m4a": "audio/mp4",
        "aac": "audio/aac",
        "webm": "audio/webm",
    }

    content_type = content_types.get(
        audio_format.lower(),
        "audio/wav",
    )

    url = (
        f"{GHANANLP_BASE_URL}"
        f"/asr/v2/transcribe?language={language}"
    )

    headers = {
        "Content-Type": content_type,
        "Ocp-Apim-Subscription-Key": GHANANLP_API_KEY,
    }

    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(
            url,
            headers=headers,
            content=audio_bytes,
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=(
                f"GhanaNLP ASR failed "
                f"({response.status_code}): {response.text[:500]}"
            ),
        )

    return response.text.strip()


def call_openai_with_fallback(
    message: str,
    conversation_id: str,
    language: str,
) -> tuple[str, str]:
    """
    Try to call OpenAI LLM with timeout and fallback to KofiEngine.
    
    Returns: (response_text, tool_used) where tool_used is "openai" or "kofi_fallback"
    """
    if not openai_client:
        logger.info(
            f"OpenAI not configured (conversation_id={conversation_id}), "
            "using KofiEngine fallback"
        )
        return kofi.process(message, language, conversation_id)["message"], "kofi_fallback"

    try:
        # Get conversation history for context
        history = conversations.get(conversation_id, [])
        messages = [
            {"role": msg["role"], "content": msg["content"]}
            for msg in history[-10:]  # Use last 10 messages for context
        ]
        messages.append({"role": "user", "content": message})

        logger.info(f"Calling OpenAI (conversation_id={conversation_id}, model={OPENAI_MODEL})")
        
        response = openai_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[{"role": "system", "content": SYSTEM_PROMPT}] + messages,
            timeout=OPENAI_TIMEOUT,
            temperature=0.7,
            max_tokens=500,
        )

        result = response.choices[0].message.content.strip()
        logger.info(f"OpenAI call succeeded (conversation_id={conversation_id})")
        return result, "openai"

    except (APIError, APIConnectionError, APITimeoutError) as e:
        logger.warning(
            f"OpenAI call failed for conversation_id={conversation_id}: {e}. "
            "Falling back to KofiEngine."
        )
        return kofi.process(message, language, conversation_id)["message"], "kofi_fallback"
    except Exception as e:
        logger.error(
            f"Unexpected error calling OpenAI (conversation_id={conversation_id}): {e}. "
            "Falling back to KofiEngine."
        )
        return kofi.process(message, language, conversation_id)["message"], "kofi_fallback"


@app.get("/")
def root() -> Dict[str, Any]:
    return {
        "name": APP_NAME,
        "version": APP_VERSION,
        "status": "running",
        "service": "GeoHarvest Kofi",
    }


@app.get("/health")
def health() -> Dict[str, Any]:
    return {
        "status": "ok",
        "service": APP_NAME,
        "version": APP_VERSION,
        "ghananlp_configured": bool(GHANANLP_API_KEY),
        "openai_configured": bool(OPENAI_API_KEY),
    }


@app.post(
    "/api/v1/ai/chat",
    response_model=ChatResponse,
)
def chat(request: ChatRequest) -> ChatResponse:

    language = normalize_language(request.language)

    conversation_id = get_or_create_conversation(
        request.conversation_id
    )

    save_message(
        conversation_id,
        "user",
        request.message,
        language,
    )

    # Try OpenAI first with fallback to KofiEngine
    response_text, tool_used = call_openai_with_fallback(
        request.message,
        conversation_id,
        language,
    )

    save_message(
        conversation_id,
        "assistant",
        response_text,
        language,
    )

    return ChatResponse(
        type="response",
        conversation_id=conversation_id,
        message=response_text,
        language=language,
        detected_intent=None,
        tool_used=tool_used,
        tool_result=None,
        requires_confirmation=False,
        pending_action=None,
        actions=[],
        navigation=None,
        suggested_actions=[],
        expires_at=None,
    )


@app.post(
    "/api/v1/ai/voice",
    response_model=VoiceResponse,
)
async def voice(request: VoiceRequest) -> VoiceResponse:

    try:
        audio_bytes = base64.b64decode(
            request.audio,
            validate=True,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid base64 audio: {exc}",
        )

    if not audio_bytes:
        raise HTTPException(
            status_code=400,
            detail="Audio payload is empty.",
        )

    transcript = await ghananlp_transcribe(
        audio_bytes=audio_bytes,
        language=request.language,
        audio_format=request.audio_format,
    )

    if not transcript:
        raise HTTPException(
            status_code=422,
            detail="Speech recognition returned an empty transcript.",
        )

    language = normalize_language(request.language)

    conversation_id = get_or_create_conversation(None)

    save_message(
        conversation_id,
        "user",
        transcript,
        language,
    )

    # Try OpenAI first with fallback to KofiEngine
    response_text, tool_used = call_openai_with_fallback(
        transcript,
        conversation_id,
        language,
    )

    save_message(
        conversation_id,
        "assistant",
        response_text,
        language,
    )

    return VoiceResponse(
        transcript=transcript,
        language=language,
        ai=ChatResponse(
            type="response",
            conversation_id=conversation_id,
            message=response_text,
            language=language,
            detected_intent=None,
            tool_used=tool_used,
            tool_result=None,
            requires_confirmation=False,
            pending_action=None,
            actions=[],
            navigation=None,
            suggested_actions=[],
            expires_at=None,
        ),
    )


@app.get("/api/v1/ai/conversations")
def get_conversations() -> Dict[str, Any]:
    return {
        "conversations": [
            {
                "id": conversation_id,
                "messages": messages[-10:],
            }
            for conversation_id, messages in conversations.items()
        ]
    }


@app.get("/api/v1/ai/conversations/{conversation_id}")
def get_conversation(
    conversation_id: str,
) -> Dict[str, Any]:

    if conversation_id not in conversations:
        raise HTTPException(
            status_code=404,
            detail="Conversation not found.",
        )

    return {
        "id": conversation_id,
        "messages": conversations[conversation_id],
    }
