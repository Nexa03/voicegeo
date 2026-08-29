from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import random
import uuid
from datetime import datetime

app = FastAPI(title="GeoHarvest AI API", version="1.0.0")

# CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Models
class ChatRequest(BaseModel):
    message: str
    language: str = "tw"
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
    actions: List[Any] = []
    navigation: Optional[Dict[str, Any]] = None
    suggested_actions: List[Any] = []
    expires_at: Optional[str] = None

class VoiceRequest(BaseModel):
    audio: str  # base64 encoded
    language: str = "tw"

# Demo AI Brain
class DemoAIBrain:
    def __init__(self):
        self.conversations: Dict[str, List[Dict]] = {}
        
    def process_message(self, message: str, language: str = "tw", conversation_id: Optional[str] = None) -> Dict:
        # Create or get conversation
        if not conversation_id or conversation_id not in self.conversations:
            conversation_id = str(uuid.uuid4())
            self.conversations[conversation_id] = []
        
        history = self.conversations[conversation_id]
        history.append({"role": "user", "content": message, "language": language})
        
        # Generate response
        response = self._generate_response(message, language, history)
        
        history.append({"role": "assistant", "content": response["message"], "language": language})
        
        # Keep only last 20 messages
        if len(history) > 20:
            self.conversations[conversation_id] = history[-20:]
        
        return response
    
    def _generate_response(self, message: str, language: str, history: List[Dict]) -> Dict:
        lower = message.lower()
        
        # Intent detection
        intent = "general_chat"
        tool_used = None
        tool_result = None
        requires_confirmation = False
        
        if any(word in lower for word in ['hello', 'hi', 'hey', 'good morning', 'good afternoon']):
            intent = "greeting"
            response_text = self._greeting(language)
        elif any(word in lower for word in ['price', 'bo', 'cost', 'how much', 'sika']):
            intent = "check_price"
            tool_used = "get_market_prices"
            tool_result = {"crop": "tomato", "price": "GH₵5.50/kg", "market": "Techiman"}
            response_text = self._price_response(language)
        elif any(word in lower for word in ['buyer', 'tɔ', 'sell', 'market', 'customer']):
            intent = "find_buyer"
            tool_used = "search_buyers"
            tool_result = {"count": 3, "best_match": "Kwame Agri - 5km away"}
            response_text = self._buyer_response(language)
        elif any(word in lower for word in ['transport', 'truck', 'car', 'kaboom', 'delivery']):
            intent = "find_transport"
            tool_used = "find_transporters"
            tool_result = {"count": 2, "eta": "2 hours", "cost": "GH₵200"}
            response_text = self._transport_response(language)
        elif any(word in lower for word in ['weather', 'nsuo', 'rain', 'sun', 'dry']):
            intent = "check_weather"
            tool_used = "get_weather"
            tool_result = {"condition": "Partly cloudy", "temp": "28°C", "rain_chance": "20%"}
            response_text = self._weather_response(language)
        elif any(word in lower for word in ['help', 'boa', 'assist', 'what can you do']):
            intent = "help"
            response_text = self._help_response(language)
        elif any(word in lower for word in ['thank', 'meda', 'thanks']):
            intent = "thanks"
            response_text = self._thanks_response(language)
        elif any(word in lower for word in ['order', 'track', 'status']):
            intent = "track_order"
            tool_used = "get_order"
            tool_result = {"order_id": "GH-2024-001", "status": "In transit", "eta": "Today 3pm"}
            response_text = self._order_response(language)
        else:
            intent = "general_chat"
            response_text = self._default_response(language)
        
        return {
            "type": "response",
            "conversation_id": "demo",
            "message": response_text,
            "language": language,
            "detected_intent": intent,
            "tool_used": tool_used,
            "tool_result": tool_result,
            "requires_confirmation": requires_confirmation,
            "pending_action": None,
            "actions": [],
            "navigation": None,
            "suggested_actions": [],
            "expires_at": None,
        }
    
    def _greeting(self, lang: str) -> str:
        if lang == 'tw':
            return "Akwaaba! Me yɛ Kofi, wo assistant. Mepɛ sɛ meboa wo. Mepɛ sɛ mehu wo asɛm?"
        elif lang == 'gaa':
            return "Akpe! Nye Kofi, wo assistant. Mepɛ me hee wo."
        elif lang == 'en-GH':
            return "Hello! I'm Kofi, your assistant. How can I help you today?"
        return "Hello! I'm Kofi."
    
    def _price_response(self, lang: str) -> str:
        if lang == 'tw':
            return "Tomato bo yɛ GH₵5.50 kilo baako. Yam yɛ GH₵3.20. Garden egg yɛ GH₵4.00. Wopɛ sɛ mekyerɛ wo anaa?"
        elif lang == 'en-GH':
            return "Tomato is GH₵5.50/kg. Yam is GH₵3.20. Garden egg is GH₵4.00. Want me to show more?"
        return "Tomato: GH₵5.50/kg."
    
    def _buyer_response(self, lang: str) -> str:
        if lang == 'tw':
            return "Mahu buyers abiɛsa a wɔpɛ tomato wɔ Techiman. Kwame Agri yɛ ɔbɛn wo paa - 5 km. Ɔpɛ crates 15. Wopɛ sɛ mekyerɛ wo?"
        elif lang == 'en-GH':
            return "I found 3 buyers for tomato in Techiman. Kwame Agri is closest - 5km. They want 15 crates. Show you?"
        return "Found 3 buyers in Techiman."
    
    def _transport_response(self, str) -> str:
        if lang == 'tw':
            return "Mahu transporters abiɛsa wɔ Wenchi. Wɔbɛtumi abɔ wo GH₵200. Ɔbɛn wo paa no bɛba wɔ 2 hours. Wopɛ sɛ mefrɛ wo?"
        elif lang == 'en-GH':
            return "Found 3 transporters in Wenchi. Cost is GH₵200. Closest arrives in 2 hours. Call them?"
        return "Found transporters. GH₵200, 2 hours."
    
    def _weather_response(self, lang: str) -> str:
        if lang == 'tw':
            return "Nsuo bɛtɔ nnɛ. Wobɛtumi adua wɔ wo farm. Yei yɛ dwuma ma wo crops."
        elif lang == 'en-GH':
            return "Rain expected today. Good for your farm. Your crops will benefit."
        return "Rain expected today."
    
    def _help_response(self, lang: str) -> str:
        if lang == 'tw':
            return "Mebɔ tumi: 1. Hwehwɛ buyers 2. Check prices 3. Find transport 4. Check weather 5. Track orders. Ka asɛm no!"
        elif lang == 'en-GH':
            return "I can help: 1. Find buyers 2. Check prices 3. Find transport 4. Check weather 5. Track orders. Just ask!"
        return "I can help with: buyers, prices, transport, weather, orders."
    
    def _thanks_response(self, lang: str) -> str:
        if lang == 'tw':
            return "Yiw! Meda wo ase. Biribi foforo bi?"
        elif lang == 'en-GH':
            return "You're welcome! Anything else?"
        return "You're welcome!"
    
    def _order_response(self, lang: str) -> str:
        if lang == 'tw':
            return "Wo order no wɔ kwan so. Ɔbɛba nnɛ wɔ 3pm. Tracking code yɛ GH-2024-001."
        elif lang == 'en-GH':
            return "Your order is in transit. Arriving today at 3pm. Tracking: GH-2024-001"
        return "Order in transit. ETA: today 3pm."
    
    def _default_response(self, lang: str) -> str:
        if lang == 'tw':
            return "Menya wo asɛm. Mpɛ meboa wo. Kɔkɔɔ ka asɛm no bio anaa."
        elif lang == 'en-GH':
            return "I understand. Let me help you. Could you tell me more?"
        return "I understand. How can I help?"

ai_brain = DemoAIBrain()

# Routes
@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/api/v1/ai/chat", response_model=ChatResponse)
def chat(request: ChatRequest):
    try:
        response = ai_brain.process_message(
            message=request.message,
            language=request.language,
            conversation_id=request.conversation_id,
        )
        return ChatResponse(**response)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/v1/ai/voice")
def voice(request: VoiceRequest):
    # Voice endpoint - in production, this would do ASR first
    # For now, treat the base64 audio as a text message
    try:
        import base64
        # Decode audio (in production, pass to ASR)
        # audio_bytes = base64.b64decode(request.audio)
        
        response = ai_brain.process_message(
            message="[Voice message]",
            language=request.language,
        )
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/ai/conversations")
def get_conversations():
    return {
        "conversations": [
            {"id": conv_id, "messages": msgs[-5:]} 
            for conv_id, msgs in ai_brain.conversations.items()
        ]
    }

@app.get("/api/v1/ai/conversations/{conversation_id}")
def get_conversation(conversation_id: str):
    if conversation_id not in ai_brain.conversations:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return {
        "id": conversation_id,
        "messages": ai_brain.conversations[conversation_id]
    }
