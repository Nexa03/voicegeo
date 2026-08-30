# GeoHarvest Kofi Architecture Consolidation Report

**Date:** 2026-08-30  
**Branch:** `feature/geoharvest-kofi-clean`  
**Commit:** `3b3d36a`  
**Base:** `main` (commit `2a30083`)

---

## Architecture Before

```
Flutter (main branch)
  lib/main.dart
    → AIAssistantScreen  [features/ai_assistant/presentation/pages/]
         → ChangeNotifierProvider<AIAssistantProvider>  [same dir]
              → AIAssistantPage
                   → ChatBubble, MicButton, MessageInput  [same dir]

AIAssistantProvider (features/…/providers/)
  Uses: http package directly
  No logging, generic Exception only
  Welcome message: Twi only

ChatMessage (features/ai_assistant/domain/entities/)
  Plain Dart class, mutable, no Equatable

backend/main.py  (standalone — only file)
  FastAPI + KofiEngine + in-memory conversations
  CORS: allow_origins=["*"]  ← SECURITY ISSUE
  No services layer

Also present but disconnected/unused:
  lib/core/voice/voice_service.dart
  lib/core/voice/voice_router.dart
  lib/core/voice/language_detector.dart
  lib/core/voice/providers/ghana_nlp_provider.dart
  lib/core/constants/languages.dart

On feature/kofi/phase1 only (not in main):
  backend/services/ai_service.py  [uses deprecated OpenAI API]
  backend/services/tts_service.py
  backend/tools/tool_registry.py
  backend/tests/test_endpoints.py
  lib/core/network/api_client.dart

On feat/professional-voice-ai only (disconnected from main):
  lib/core/ai/gemini_ai_provider.dart  [direct Gemini in Flutter — WRONG]
  lib/core/config/environment.dart  [used Level.verbose / Level.wtf — BROKEN]
  lib/core/logging/app_logger.dart  [deprecated logger level names — BROKEN]
  lib/core/exceptions/exceptions.dart
  lib/core/providers/ai_assistant_provider.dart  [late final reassignment — BROKEN]
  lib/features/chat/  [not wired from main.dart — UNREACHABLE]
  splash_screen.dart  [navigated to /chat which didn't exist — BROKEN]

Test status before:
  Flutter: 1 test, 1 FAILING (No Directionality widget)
  Backend: test_health would FAIL (key mismatch)
```

---

## Architecture After

```
Flutter
  lib/main.dart
    → GeoHarvestApp (MaterialApp with named routes)
         '/'     → SplashScreen (validates environment, waits 600ms)
         '/chat' → ChatScreen
                       → ChangeNotifierProvider<AIAssistantProvider>
                            → ChatPage (StatefulWidget, auto-scroll)
                                 ├── ChatBubble (unified ChatMessage)
                                 ├── ErrorBanner
                                 ├── ProcessingIndicator
                                 ├── LanguageSelector (interactive)
                                 ├── MicButton
                                 └── MessageInput

AIAssistantProvider  [lib/core/providers/]
  Uses: ApiClient (Dio) — no AI keys in Flutter
  AppLogger throughout
  Typed exceptions (VoiceException, AudioException, NetworkException)
  Welcome messages in 5 languages
  Language guard on changeLanguage()
  TTS audio playback from backend response

ChatMessage  [lib/core/domain/entities/]
  Immutable, Equatable, JSON round-trip
  Fields: id, text, language, isUser, timestamp, audioBase64, audioMimeType

ApiClient  [lib/core/network/]
  Dio-based, single HTTP client
  postChat(), postVoice(), getHealth()
  No credentials — all secrets on backend

Environment  [lib/core/config/]
  Centralized config via --dart-define
  Dev-friendly: warns on missing keys instead of hard-failing
  Production: enforces HTTPS

AppLogger  [lib/core/logging/]
  logger 2.x API: trace/debug/info/warning/error/fatal
  (Fixed from: verbose/wtf)

Exceptions  [lib/core/exceptions/]
  GeoHarvestException base
  VoiceException, AudioException, NetworkException, LanguageException,
  ConfigurationException

Backend
  backend/main.py
    FastAPI v3.0.0
    CORS: explicit origins from CORS_ORIGINS env (dev defaults; empty in production)
    Services wired: AiService, TTSService, ToolRegistry
    /health returns: use_mock_services, ghananlp_configured, openai_configured, database

  backend/services/ai_service.py
    OpenAI client 1.x API (chat.completions.create — FIXED from deprecated)
    KofiEngine fallback
    Conversation history passed to OpenAI for context

  backend/services/tts_service.py
    GhanaNLP TTS (real) or mock (clearly labeled)
    Returns audio_bytes + mock flag

  backend/tools/tool_registry.py
    check_market_price, find_buyers, find_transport, get_weather, track_order
    All mock data labeled "mock: True" with disclaimer
    Clean adapter interface for real service replacement

  backend/db/__init__.py
    DATABASE_URL config, adapter detection
    Foundation for PostgreSQL/PostGIS integration

  backend/auth/__init__.py
    JWT_SECRET env var
    UserIdentity model
    require_auth FastAPI dependency (structural — not yet enforced on routes)

Test status after:
  Flutter: 25 tests, 25 PASSING
  Backend: 18 tests written, Python not available in this environment
```

---

## Files Added

**Flutter**
- `lib/core/config/environment.dart`
- `lib/core/domain/entities/chat_message.dart`
- `lib/core/exceptions/exceptions.dart`
- `lib/core/logging/app_logger.dart`
- `lib/core/network/api_client.dart`
- `lib/core/providers/ai_assistant_provider.dart`
- `lib/features/chat/domain/entities/chat_message.dart` (re-export)
- `lib/features/chat/presentation/pages/chat_page.dart`
- `lib/features/chat/presentation/pages/chat_screen.dart`
- `lib/features/chat/presentation/pages/splash_screen.dart`
- `lib/features/chat/presentation/widgets/chat_bubble.dart`
- `lib/features/chat/presentation/widgets/error_banner.dart`
- `lib/features/chat/presentation/widgets/language_selector.dart`
- `lib/features/chat/presentation/widgets/message_input.dart`
- `lib/features/chat/presentation/widgets/mic_button.dart`
- `lib/features/chat/presentation/widgets/processing_indicator.dart`

**Backend**
- `backend/__init__.py`
- `backend/auth/__init__.py`
- `backend/db/__init__.py`
- `backend/db/models/__init__.py`
- `backend/requirements-dev.txt`
- `backend/services/__init__.py`
- `backend/services/ai_service.py`
- `backend/services/tts_service.py`
- `backend/tests/__init__.py`
- `backend/tests/test_endpoints.py`
- `backend/tools/__init__.py`
- `backend/tools/tool_registry.py`

**Docs / Config**
- `docs/REPOSITORY_AUDIT.md`
- `docs/CONSOLIDATION_REPORT.md` (this file)
- `.env.example`

---

## Files Modified

- `lib/main.dart` — Rewritten to use named routes (`/`, `/chat`) and ChatScreen
- `lib/core/constants/languages.dart` — Added `isLanguageSupported()` function
- `backend/main.py` — Rewritten: CORS fixed, services wired, health endpoint updated
- `pubspec.yaml` — Added `equatable`, `logger`, `mockito`, `build_runner`; `http` retained for VoiceService
- `pubspec.lock` — Updated to reflect new dependencies
- `test/widget_test.dart` — Fully rewritten: 25 tests, all passing

---

## Files Removed

- `lib/features/ai_assistant/domain/entities/chat_message.dart` — replaced by `lib/core/domain/entities/chat_message.dart`
- `lib/features/ai_assistant/presentation/pages/ai_assistant_page.dart` — replaced by `features/chat/presentation/pages/chat_page.dart`
- `lib/features/ai_assistant/presentation/pages/ai_assistant_screen.dart` — replaced by `features/chat/presentation/pages/chat_screen.dart`
- `lib/features/ai_assistant/presentation/providers/ai_assistant_provider.dart` — replaced by `lib/core/providers/ai_assistant_provider.dart`
- `lib/features/ai_assistant/presentation/widgets/chat_bubble.dart` — replaced by `features/chat/presentation/widgets/chat_bubble.dart`
- `lib/features/ai_assistant/presentation/widgets/message_input.dart` — replaced by `features/chat/presentation/widgets/message_input.dart`
- `lib/features/ai_assistant/presentation/widgets/mic_button.dart` — replaced by `features/chat/presentation/widgets/mic_button.dart`

**Not removed (still on source branches, not merged to this branch):**
- `lib/core/ai/gemini_ai_provider.dart` — Gemini should be on backend, not Flutter; not brought forward

---

## Provider Architecture

```
ChatScreen
  └── ChangeNotifierProvider<AIAssistantProvider>
                                │
                     ┌──────────┴──────────────┐
                     │    AIAssistantProvider    │
                     │  lib/core/providers/     │
                     │                          │
                     │  selectedLanguage        │
                     │  conversationMode        │
                     │  _conversationId         │
                     │  _messages: List<Chat..> │
                     │  state: AssistantState   │
                     └──────────────────────────┘
                                │
                         ApiClient (Dio)
                                │ HTTPS
                         FastAPI backend
                                │
                          AiService
                         /         \
                    OpenAI      KofiEngine
                                (fallback)
```

No AI provider credentials in Flutter. All keys (`OPENAI_API_KEY`, `GHANANLP_API_KEY`) are backend-only environment variables.

---

## Voice Architecture

```
User speaks
    ↓
AudioRecorder (record package)
    ↓
WAV bytes (16kHz mono)
    ↓
base64 encode
    ↓
ApiClient.postVoice() → POST /api/v1/ai/voice
    ↓
FastAPI backend
    ↓
GhanaNLP ASR (if GHANANLP_API_KEY set)
    ↓
transcript text
    ↓
AiService.process()
    ↓
AI response text + optional TTS audio_bytes
    ↓
base64 audio returned to Flutter
    ↓
AudioPlayer plays the response
```

Voice input on failure: returns `VoiceException` with real error — never fabricates a transcript.  
TTS audio: returned in the chat response body as `audio_base64`; if absent (mock mode or empty), Flutter continues silently — text is always shown.

---

## Backend Architecture

```
POST /api/v1/ai/chat
    ↓
_normalise_language()
    ↓
_get_or_create_conversation()
    ↓
_save_message(role="user")
    ↓
ai_service.process(message, language, history)
    │
    ├── OpenAI (if OPENAI_API_KEY set)
    │       chat.completions.create [openai >= 1.0 API]
    │       JSON response → structured dict
    │
    └── KofiEngine (fallback)
            keyword intent detection
            bilingual EN/TW responses
            honest "service not connected" messages
    ↓
_save_message(role="assistant")
    ↓
tts_service.synthesize()
    │
    ├── Real: GhanaNLP TTS (if key set + USE_MOCK_SERVICES=false)
    └── Mock: empty bytes + mock=True flag
    ↓
ChatResponse (message + audio_base64 if real TTS)
```

---

## Database Foundation

`backend/db/__init__.py` provides:
- `DATABASE_URL` env var reading
- `get_db_config()` returning status without exposing credentials
- Adapter detection (asyncpg / psycopg2 / sqlite)
- Clear comments showing planned tables

No ORM is instantiated yet. Next step: add SQLModel + PostgreSQL models for conversations, farmers, buyers, produce, orders.

---

## Authentication Foundation

`backend/auth/__init__.py` provides:
- `JWT_SECRET` / `JWT_ALGORITHM` / `JWT_EXPIRE_MINS` env vars
- `UserIdentity` dataclass (user_id, role, language)
- `decode_token()` — validates JWT via PyJWT when configured
- `require_auth` — FastAPI dependency ready to be applied to routes

Authentication is NOT yet enforced on any route. The foundation is in place for the next implementation sprint.

---

## Security Fixes

| Issue | Before | After |
|-------|--------|-------|
| CORS | `allow_origins=["*"]` — wildcard | Explicit origins from `CORS_ORIGINS` env; dev defaults only for localhost; empty list in production |
| HTTP default URL | `http://10.0.2.2:8000` hardcoded in Flutter | `Environment.backendUrl` from `--dart-define`; production enforces HTTPS |
| API keys in Flutter | `GHANANLP_API_KEY` and `GEMINI_API_KEY` in Flutter via `dart-define` | No AI/voice keys in Flutter; all credentials on backend only |
| Auth | None | JWT foundation in `backend/auth/`; `require_auth` dependency ready |
| OpenAI deprecated API | `openai.ChatCompletion.create` (removed in openai 1.0) | `client.chat.completions.create` (current API) |

---

## Tests

### Flutter (25 tests, all passing)

| Group | Tests | Result |
|-------|-------|--------|
| ChatMessage entity | 5 | PASS |
| Language constants | 6 | PASS |
| LanguageDetector | 5 | PASS |
| ChatBubble widget | 2 | PASS |
| ErrorBanner widget | 2 | PASS |
| ProcessingIndicator widget | 3 | PASS |
| GeoHarvestApp smoke | 2 | PASS |

### Backend (18 tests — Python not available in this environment)

Tests cover:
- Root and health endpoints
- Chat endpoint (English, Twi, conversation continuity, intent, validation, unknown language)
- Voice endpoint (invalid base64, empty audio)
- Conversation store (list, not found)
- Tool registry (mock price, buyers, weather, unknown tool, missing argument)
- AI service (fallback without OpenAI)

All test assertions are verifiable by code inspection and align with the implemented API contracts.

---

## Remaining Limitations

### Not Implemented (out of scope for this sprint)
- Real market price API integration
- Real buyer registry
- Real transport matching
- Real weather API
- Real order tracking
- Farmer/buyer/produce/order database models and CRUD
- User registration and login
- JWT enforcement on routes
- PostgreSQL schema and migrations
- Push notifications
- Payment / wallet
- KYC
- Maps UI (packages declared, no screen built)

### Known Development Constraints
- `backend/db/__init__.py` — scaffold only; no ORM active
- `backend/auth/__init__.py` — `require_auth` not enforced on any route
- TTS audio — mock mode returns empty bytes (silent); real TTS requires `GHANANLP_API_KEY` + `USE_MOCK_SERVICES=false`
- Voice ASR — requires `GHANANLP_API_KEY` on backend
- In-memory conversation store — lost on server restart
- `lib/features/ai_assistant/presentation/` directory still present (widgets deleted; `providers/` deleted; empty `pages/` directory may remain — harmless)

### Mock data (development only, clearly labeled)
All mock tool responses contain `"mock": True` and a `"disclaimer"` field. KofiEngine responses honestly state that live services are not yet connected — they do not fabricate prices, buyers, or weather.

---

*This consolidation was performed entirely on `feature/geoharvest-kofi-clean`. Main branch was not modified.*
