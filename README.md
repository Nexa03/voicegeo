# VoiceGeo — Voice-First Agricultural AI for Ghana

VoiceGeo is a Flutter + FastAPI voice assistant that helps Ghanaian farmers access agricultural services (market prices, buyers, transport, weather) via **voice input in Twi, English, or mixed code-switch**.

---

## Features

- **Voice-first interface** – speak in Twi or English and get responses in your language
- **Kofi AI assistant** – rule-based engine ready for OpenAI integration
- **GhanaNLP integration** – automatic speech recognition (ASR), text-to-speech (TTS), and translation powered by [GhanaNLP](https://ghananlp.org)
- **Conversation history** – maintains context per session
- **Cross-platform** – Flutter app for Android, iOS, web, and desktop; FastAPI backend

---

## Prerequisites

- **Flutter** 3.10+
- **Python** 3.9+
- **Docker** & **Docker Compose** (optional, for backend)
- **GHANANLP_API_KEY** – Required for all voice features (get one at [https://ghananlp.org](https://ghananlp.org))

---

## Quick Start

### Backend (FastAPI)

#### Option A: Local Python

```bash
cd backend
pip install -r requirements.txt
export GHANANLP_API_KEY=your-api-key-here
export GHANANLP_BASE_URL=https://translation-api.ghananlp.org  # optional, defaults shown
python main.py
# Backend runs on http://localhost:8000
```

#### Option B: Docker

```bash
cd backend
export GHANANLP_API_KEY=your-api-key-here
export GHANANLP_BASE_URL=https://translation-api.ghananlp.org  # optional
docker-compose up
# Backend runs on http://localhost:8000
```

---

### Flutter App

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run on Android Emulator:**
   ```bash
   flutter run \
     --dart-define=GHANANLP_API_KEY=your-api-key-here \
     --dart-define=GEOHARVEST_BACKEND_URL=http://10.0.2.2:8000
   ```
   - Android emulator sees host via `10.0.2.2` (special alias)

3. **Run on Physical Device/iOS:**
   ```bash
   flutter run \
     --dart-define=GHANANLP_API_KEY=your-api-key-here \
     --dart-define=GEOHARVEST_BACKEND_URL=http://YOUR-LAN-IP:8000
   ```
   - Replace `YOUR-LAN-IP` with your machine's local network IP (e.g., `192.168.1.100`)
   - Device must be on the same Wi-Fi network

4. **Run on Web:**
   ```bash
   flutter run -d chrome \
     --dart-define=GHANANLP_API_KEY=your-api-key-here \
     --dart-define=GEOHARVEST_BACKEND_URL=http://YOUR-LAN-IP:8000
   ```

5. **Run on Desktop (macOS/Linux/Windows):**
   ```bash
   flutter run -d linux \
     --dart-define=GHANANLP_API_KEY=your-api-key-here \
     --dart-define=GEOHARVEST_BACKEND_URL=http://localhost:8000
   ```

---

## Key Environment Variables

### Backend
| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `GHANANLP_API_KEY` | ✅ Yes | — | API key for ASR/TTS/translation |
| `GHANANLP_BASE_URL` | ❌ No | `https://translation-api.ghananlp.org` | GhanaNLP endpoint |
| `OPENAI_API_KEY` | ❌ No | — | (Currently unused; for future enhancement) |

### Flutter App
| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `GHANANLP_API_KEY` | ✅ Yes | — | API key for voice features |
| `GEOHARVEST_BACKEND_URL` | ✅ Yes | — | Backend URL (see platform-specific values above) |

---

## Project Structure

```
voicegeo/
├── lib/
│   ├── features/ai_assistant/          # Chat & voice UI
│   │   ├── presentation/
│   │   │   ├── pages/ai_assistant_page.dart
│   │   │   └── widgets/                # MicButton, MessageInput, ChatBubble
│   │   ├── domain/
│   │   │   └── entities/chat_message.dart
│   │   └── data/
│   ├── core/
│   │   ├── voice/
│   │   │   ├── voice_service.dart
│   │   │   └── voice_router.dart       # ASR/TTS/translation failover logic
│   │   └── constants/
│   └── main.dart
├── backend/
│   ├── main.py                         # FastAPI entry point
│   ├── docker-compose.yml
│   └── requirements.txt
└── README.md
```

---

## API Endpoints

### Chat (Text Input)
**POST** `/api/v1/ai/chat`
```json
{
  "message": "What is the price of tomatoes?",
  "language": "tw",
  "conversation_id": "optional-uuid"
}
```

### Voice (Audio Input)
**POST** `/api/v1/ai/voice`
```json
{
  "audio": "base64-encoded-wav-or-mp3",
  "language": "tw",
  "audio_format": "wav"
}
```

### Get Conversations
**GET** `/api/v1/ai/conversations` – list all conversations  
**GET** `/api/v1/ai/conversations/{conversation_id}` – get conversation history

---

## Troubleshooting

### "GHANANLP_API_KEY is not configured"
- Ensure you exported/passed `GHANANLP_API_KEY` to both backend and Flutter app
- For Docker: check `docker-compose.yml` forwards the env var
- For Flutter: pass `--dart-define=GHANANLP_API_KEY=...` to `flutter run`

### "Failed to connect to backend"
- Check backend is running: `curl http://localhost:8000/`
- Verify `GEOHARVEST_BACKEND_URL` matches your setup:
  - Android emulator → `http://10.0.2.2:8000`
  - Physical device → `http://<your-lan-ip>:8000` (check with `ifconfig` / `ipconfig`)
  - Desktop → `http://localhost:8000`

### Mic button gets stuck in "Listening"
- This should be fixed in the current version (see Issue #1 fix)
- Try restarting the app if it still occurs

---

## Development

### Run Backend Tests
```bash
cd backend
pip install pytest pytest-asyncio httpx
pytest
```

### Format Code
```bash
# Flutter
dart format lib/

# Python
pip install black
black backend/
```

---

## License

MIT

---

## Support

For bugs, feature requests, or questions, open an issue on [GitHub](https://github.com/Nexa03/voicegeo/issues).
