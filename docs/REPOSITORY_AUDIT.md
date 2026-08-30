# GeoHarvest AI Repository Audit

**Audit Date:** 2026-08-30  
**Audited By:** Senior Software Engineer / Repository Auditor  
**Repository:** https://github.com/Nexa03/voicegeo  
**Local Path:** C:\Users\Johannes\voicegeo  
**Audit Type:** READ-ONLY — no code was modified, deleted, committed, or pushed.

---

## Executive Summary

The GeoHarvest AI repository contains a Flutter mobile application backed by a Python/FastAPI server, built by at least two parallel development tracks. The project is early-stage: the voice, AI, and language infrastructure is well-architected and partially working, but every GeoHarvest business feature (marketplace, farmers, buyers, logistics, payments, maps, weather, orders) is either a stub, a mock, or not implemented. The four branches each contribute unique value and must be cherry-picked or merged carefully — none of them alone represents the correct final architecture. The codebase has no critical committed secrets, but carries several security, code-quality, and testing deficiencies that must be addressed before any production deployment.

**Critical finding:** Commit `e92a028` on the git history contains an AI assistant's chain-of-thought text as its commit message — an apparent accident that should be noted in team documentation.

---

## Git State

| Item | Value |
|------|-------|
| Current Branch | `main` |
| Remote | `origin` → `https://github.com/Nexa03/voicegeo.git` |
| Working Tree | Dirty — 7 platform-generated plugin registration files modified (not source code) |
| HEAD Commit | `2a30083` — "Update VoiceGeo" |

### All Branches

| Branch | Latest Commit | Summary |
|--------|---------------|---------|
| `main` | `2a30083` | Canonical Flutter + FastAPI + KofiEngine base |
| `feature/kofi/phase1` | `c1c000b` | Adds backend services layer (ai_service, tts_service, tool_registry, tests) + Dio API client |
| `feature/kofi/phase2` | `6bae823` | Adds database scaffolding placeholder (`backend/db/__init__.py`) |
| `feat/professional-voice-ai` | `db92647` | Adds Gemini AI provider, environment config, structured logging, exception hierarchy, professional chat UI |

### Anomalous Commit

Commit `e92a028` (on phase1 branch ancestry) has the commit message:

> "The file content is large, but we need to include the full content. The create_or_update_file call earlier failed due to missing sha; we retrieved the blob sha earlier and attempted. Now need to call create_or_update_file with full content and sha..."

This is an AI assistant's internal reasoning accidentally committed as a git message. The commit itself contains legitimate code. The message is not a security issue but is unprofessional and should be documented.

---

## Branch Comparison

### Files unique to `main` (not in phase1/phase2)

None — main is a subset of phase1 content.

### Files unique to `feature/kofi/phase1`

- `backend/services/ai_service.py` — OpenAI integration with KofiEngine fallback
- `backend/services/tts_service.py` — TTS stub (mock mode)
- `backend/tools/tool_registry.py` — Tool registry with mock implementations
- `backend/tests/test_endpoints.py` — Backend integration tests
- `lib/core/network/api_client.dart` — Dio-based API client

### Files unique to `feature/kofi/phase2`

- `backend/db/__init__.py` — Lightweight DB scaffolding / placeholder

### Files unique to `feat/professional-voice-ai`

- `.env.example` — Environment variable template
- `lib/core/ai/gemini_ai_provider.dart` — Google Gemini AI provider
- `lib/core/config/environment.dart` — Centralized environment/config
- `lib/core/exceptions/exceptions.dart` — Structured exception hierarchy
- `lib/core/logging/app_logger.dart` — Structured logging via `logger` package
- `lib/core/providers/ai_assistant_provider.dart` — Gemini-backed provider (at `core/` path — duplicates features path)
- `lib/features/chat/domain/entities/chat_message.dart` — ChatMessage with Equatable
- `lib/features/chat/presentation/pages/chat_page.dart` — StatefulWidget chat page with scroll control
- `lib/features/chat/presentation/pages/chat_screen.dart` — Screen wrapper using Environment config
- `lib/features/chat/presentation/pages/splash_screen.dart` — Splash / environment validation screen
- `lib/features/chat/presentation/widgets/chat_bubble.dart` — Duplicate chat bubble
- `lib/features/chat/presentation/widgets/error_banner.dart` — Reusable error banner widget
- `lib/features/chat/presentation/widgets/language_selector.dart` — Language selection dropdown
- `lib/features/chat/presentation/widgets/message_input.dart` — Duplicate message input
- `lib/features/chat/presentation/widgets/mic_button.dart` — Duplicate mic button
- `lib/features/chat/presentation/widgets/processing_indicator.dart` — Processing state widget

### Critical Inconsistency in `feat/professional-voice-ai`

`lib/main.dart` on that branch **still imports and uses `AIAssistantScreen` from the old `features/ai_assistant` path** — it does not wire to the new `ChatScreen`. The new chat UI (`features/chat/`) is unreachable from the app's entry point. The branch is architecturally incomplete.

---

## Current Architecture

```
Flutter (main branch)
  └── main.dart
       └── GeoHarvestApp
            └── AIAssistantScreen  (ai_assistant/presentation/pages/)
                 └── ChangeNotifierProvider<AIAssistantProvider>
                      └── AIAssistantPage
                           ├── ListView (ChatBubble × n)
                           ├── MicButton  → startListening / stopListening
                           └── MessageInput → processTextInput

AIAssistantProvider
  ├── VoiceRouter
  │    └── GhanaNLPProvider (ASR, TTS, Translation via GhanaNLP API)
  ├── AudioRecorder (record package)
  ├── AudioPlayer (audioplayers package)
  └── _processWithAI() → HTTP POST /api/v1/ai/chat

FastAPI (backend/main.py)
  ├── POST /api/v1/ai/chat  → KofiEngine.process()
  ├── POST /api/v1/ai/voice → ghananlp_transcribe() + KofiEngine.process()
  ├── GET  /health
  └── GET  /api/v1/ai/conversations/{id}

KofiEngine
  └── Intent detection (keyword matching)
       └── Bilingual responses (English + Twi)
            └── NO real data — all responses are static text
```

---

## Working Functionality

| Component | Status | Notes |
|-----------|--------|-------|
| Flutter app compiles | WORKING | `flutter pub get` succeeds |
| Dark theme UI renders | WORKING | Scaffold, AppBar, ListView, mic button |
| Text input → backend chat | WORKING | HTTP POST to `/api/v1/ai/chat` functional |
| Backend `/health` endpoint | WORKING | Returns JSON status |
| Backend `/` root endpoint | WORKING | Returns name/version/status |
| KofiEngine intent detection | WORKING | Keyword matching for 8 intents |
| KofiEngine bilingual responses | WORKING | English and Twi responses |
| Language detection (offline) | WORKING | Character/word pattern heuristic |
| GeoHarvestLanguage constants | WORKING | 12 Ghanaian languages defined |
| VoiceRouter fallback logic | WORKING | Primary → fallback chain for ASR/TTS/translate |
| Conversation history (in-memory) | WORKING | Server-side last 30 messages per session |
| Flutter secure storage wiring | WORKING | Package present, not yet used |
| Flutter maps wiring | WORKING | flutter_map package present, not yet used |

---

## Broken Functionality

| Component | Status | Root Cause |
|-----------|--------|------------|
| Widget test | BROKEN | `AIAssistantScreen` mounted without `MaterialApp` — no `Directionality` ancestor. Test fails to find 'Kofi' text widget. |
| Voice recording → GhanaNLP ASR | BROKEN (requires key) | `GhanaNLPProvider` throws `VoiceServiceException` if `ghananlpApiKey` is empty — correct guard, but no key is configured by default |
| TTS playback | BROKEN (requires key) | Same — GhanaNLP TTS requires API key |
| Backend voice endpoint (live ASR) | BROKEN (requires key) | `ghananlp_transcribe()` returns HTTP 503 if `GHANANLP_API_KEY` unset |
| `feat/professional-voice-ai` new UI | BROKEN | `main.dart` on that branch does not route to `ChatScreen` — new chat feature unreachable |
| SplashScreen → `/chat` route | BROKEN | No named routes defined in MaterialApp on any branch |
| Backend tests (`test_health`) | BROKEN | `test_health` asserts `"use_mock_services"` key in health response — main.py's `/health` does not include this key |
| `ai_service.py` OpenAI integration | BROKEN (if deployed) | Uses deprecated `openai.ChatCompletion.create` API (removed in openai ≥1.0). Requires update to `client.chat.completions.create`. |

---

## Partial Functionality

| Component | Status | What Works | What Doesn't |
|-----------|--------|-----------|--------------|
| Kofi AI | PARTIAL | Intent detection, bilingual responses, conversation history | No real tool calls, no real data, no LLM inference on main |
| GhanaNLP provider | PARTIAL | Full API integration code written | Requires paid API key; no fallback when key absent |
| Backend AI service (phase1) | PARTIAL | OpenAI integration structure, KofiEngine fallback | OpenAI uses deprecated API; not merged to main |
| Tool registry (phase1) | PARTIAL | Structure, argument validation, execute() method | All tools return mock data only |
| TTS service (phase1) | PARTIAL | Mock mode clearly labeled and functional as stub | Returns empty audio; no real TTS provider wired |
| Gemini AI provider (prof. branch) | PARTIAL | Full Gemini chat integration, fallback responses | Not wired to main; `_chatSession` reassignment bug (field marked `late final` but reset in `resetConversation`) |
| Environment config (prof. branch) | PARTIAL | All config variables centralised | `Environment.validate()` always throws in production if `GEMINI_API_KEY` unset; SplashScreen navigation uses non-existent route `/chat` |
| Database scaffolding (phase2) | PARTIAL | `DATABASE_URL` env var read; config returned | No ORM, no models, no tables, no queries |
| Maps integration | PARTIAL | `flutter_map`, `geolocator`, `geocoding` packages declared | No map screen, no location UI built |
| Logging (prof. branch) | PARTIAL | `AppLogger` singleton with structured output | `Level.verbose` and `Level.wtf` may not exist in current `logger` 2.x API |

---

## Duplicate Components

### 1. ChatMessage Entity

| | File A (main/phase1/phase2) | File B (professional-voice-ai) |
|-|-----------------------------|-------------------------------|
| Path | `lib/features/ai_assistant/domain/entities/chat_message.dart` | `lib/features/chat/domain/entities/chat_message.dart` |
| Differences | Plain Dart class, mutable constructor, has `audioUrl` field | Uses `Equatable`, `const` constructor, no `audioUrl` field |
| Better version | **File B** — Equatable gives value equality for free; `const` is correct for immutable data |
| Recommended action | MERGE — consolidate to single entity at `lib/core/domain/entities/chat_message.dart`; add `audioUrl` from File A; keep Equatable from File B |

### 2. AI Assistant Provider

| | File A (main/phase1/phase2) | File B (professional-voice-ai) |
|-|-----------------------------|-------------------------------|
| Path | `lib/features/ai_assistant/presentation/providers/ai_assistant_provider.dart` | `lib/core/providers/ai_assistant_provider.dart` |
| AI backend | HTTP calls to FastAPI backend via `http` package | Direct Gemini SDK calls via `GeminiAIProvider` |
| Logging | None | Structured `AppLogger` throughout |
| Error types | Generic `Exception` | Typed exceptions (`AudioException`, `VoiceException`, etc.) |
| Welcome messages | Twi only | All 5 supported languages |
| Language guard | None on `changeLanguage` | Guards against unsupported codes |
| Bug (File B) | — | `late final GeminiAIProvider aiProvider` then `aiProvider = GeminiAIProvider()` called again in `resetConversation` — reassignment of `late final` will throw at runtime |
| Better version | **File B architecture** but **File A backend routing** — GeoHarvest final architecture requires backend calls; Gemini should be invoked by the backend, not the client |
| Recommended action | MERGE — keep File B's structure, logging, typed exceptions, and multi-language welcome; replace direct Gemini calls with backend HTTP calls |

### 3. Chat Pages

| | File A (main) | File B (professional-voice-ai) |
|-|---------------|-------------------------------|
| Path | `lib/features/ai_assistant/presentation/pages/ai_assistant_page.dart` | `lib/features/chat/presentation/pages/chat_page.dart` |
| State | StatelessWidget | StatefulWidget with ScrollController |
| Auto-scroll | No | Yes — `_scrollToBottom()` on new messages |
| Language selector | Badge in AppBar only (display) | Interactive `LanguageSelector` widget in bottom bar |
| Clear dialog | Immediate clear | Confirmation dialog before clearing |
| Cancel button | None | Cancel button shown when busy |
| Better version | **File B** |
| Recommended action | KEEP File B; REMOVE File A later |

### 4. Chat Screens

| | File A (main) | File B (professional-voice-ai) |
|-|---------------|-------------------------------|
| Path | `lib/features/ai_assistant/presentation/pages/ai_assistant_screen.dart` | `lib/features/chat/presentation/pages/chat_screen.dart` |
| Config source | `String.fromEnvironment` inline | `Environment` class |
| Provider params | `backendUrl`, `ghananlpApiKey` | `backendUrl`, `ghananlpApiKey`, `geminiApiKey` |
| Better version | **File B** (centralized config) |
| Recommended action | KEEP File B; REMOVE File A later |

### 5. Chat Bubble Widget

| | File A (main) | File B (professional-voice-ai) |
|-|---------------|-------------------------------|
| Path | `lib/features/ai_assistant/presentation/widgets/chat_bubble.dart` | `lib/features/chat/presentation/widgets/chat_bubble.dart` |
| Differences | Functionally identical — same styling, same logic |
| Better version | Either (identical) |
| Recommended action | KEEP one; REMOVE the other later |

### 6. Message Input Widget

| | File A (main) | File B (professional-voice-ai) |
|-|---------------|-------------------------------|
| Path | `lib/features/ai_assistant/presentation/widgets/message_input.dart` | `lib/features/chat/presentation/widgets/message_input.dart` |
| Differences | Functionally identical |
| Recommended action | KEEP one; REMOVE the other later |

### 7. Mic Button Widget

| | File A (main) | File B (professional-voice-ai) |
|-|---------------|-------------------------------|
| Path | `lib/features/ai_assistant/presentation/widgets/mic_button.dart` | `lib/features/chat/presentation/widgets/mic_button.dart` |
| Differences | Functionally identical |
| Recommended action | KEEP one; REMOVE the other later |

### 8. KofiEngine (Backend)

Only one implementation exists in `backend/main.py`. The `ai_service.py` in phase1 wraps KofiEngine as its fallback but does not duplicate it. No conflict here — the relationship is correct.

---

## Demo / Mock / Stub Components

### Backend Tool Registry (`backend/tools/tool_registry.py`) — KEEP FOR TESTING

| Mock | Value | Classification |
|------|-------|----------------|
| Market price | 250 GHS/kg, source: `mock_market_data` | REPLACE WITH REAL SERVICE |
| Buyer | "Mock Foods Ltd.", `verified: false` | REPLACE WITH REAL SERVICE |
| Transport | "Mock Transport", capacity 2000kg, ETA 180min | REPLACE WITH REAL SERVICE |
| Weather | 28°C, 0.2 rain probability, 12 kph wind | REPLACE WITH REAL SERVICE |
| Order tracking | status: "pending", ETA: null | REPLACE WITH REAL SERVICE |

All mock functions are clearly labeled with `"mock": True` in their responses. The `USE_MOCK_SERVICES` environment variable controls whether mocks or real services are used. This is a clean pattern — keep for testing, wire real adapters behind the same interface.

### Backend TTS Service (`backend/services/tts_service.py`) — REPLACE WITH REAL SERVICE

Returns `{"mock": True, "audio_bytes": b"", ...}` in mock mode. No real TTS provider wired. The architecture is correct but the implementation is empty.

### KofiEngine Responses (`backend/main.py`) — PARTIAL — KEEP AND EXTEND

KofiEngine intentionally does NOT invent market prices, buyer counts, or transport costs. Its responses are honest placeholders ("I can check when the service is connected"). This is correct behavior for a fallback engine. Keep the engine; connect real tool calls from `tool_registry.py` when services are available.

### Gemini Fallback Responses (`lib/core/ai/gemini_ai_provider.dart`) — REPLACE WITH REAL SERVICE

The `_getFallbackResponse()` method returns hardcoded Twi/English/Ewe phrases when Gemini fails. These are labeled as fallbacks, not real AI. Acceptable as a last-resort fallback.

### In-Memory Conversation Store (`backend/main.py`) — REPLACE WITH REAL SERVICE

`conversations: Dict[str, List[...]] = {}` stores all conversation history in process memory. This is lost on server restart and does not scale. Must be replaced with PostgreSQL persistence.

### Backend DB Scaffolding (`backend/db/__init__.py`) — STUB

Returns `{"use_db": False, "database_url": ""}` when `DATABASE_URL` is not set. This is a placeholder with no ORM, models, or queries. Needs full implementation.

---

## Security Issues

### Issue 1 — CORS Wildcard (MEDIUM RISK)

| Field | Value |
|-------|-------|
| File | `backend/main.py` |
| Line | ~30 |
| Type | Unsafe CORS configuration |
| Detail | `allow_origins=["*"]` accepts requests from any origin |
| Risk | Medium — `allow_credentials=False` mitigates the worst case, but wildcard CORS is inappropriate for production |
| Fix | Replace `["*"]` with an explicit list of allowed origins: `["https://geoharvest.app", "https://api.geoharvest.app"]`. In development, read from `CORS_ORIGINS` environment variable. |

### Issue 2 — Plaintext HTTP Default URL (MEDIUM RISK)

| Field | Value |
|-------|-------|
| File | `lib/features/ai_assistant/presentation/pages/ai_assistant_screen.dart` |
| Line | ~8 |
| Type | Insecure transport |
| Detail | Default backend URL is `http://10.0.2.2:8000` (HTTP, not HTTPS) |
| Risk | Medium — acceptable for Android emulator development, but must never reach a device talking to a real server |
| Fix | For production builds, enforce `GEOHARVEST_BACKEND_URL` via `--dart-define` and validate it starts with `https://`. Add an assertion or `Environment.validate()` check. |

### Issue 3 — API Keys via Compile-Time `dart-define` (LOW-MEDIUM RISK)

| Field | Value |
|-------|-------|
| Files | `lib/features/ai_assistant/presentation/pages/ai_assistant_screen.dart`, `lib/core/config/environment.dart` |
| Type | Key exposure via compile-time constants |
| Detail | `GHANANLP_API_KEY` and `GEMINI_API_KEY` embedded via `String.fromEnvironment` and compiled into the app binary |
| Risk | Low-medium — values can be extracted from APK/IPA with tooling |
| Fix | API keys for GhanaNLP should be proxied through the FastAPI backend, not embedded in the Flutter client. The Flutter app should call the backend, which holds the key server-side. |

### Issue 4 — No Authentication on Backend (HIGH RISK for production)

| Field | Value |
|-------|-------|
| File | `backend/main.py` |
| Type | Missing authentication / authorization |
| Detail | All API endpoints are publicly accessible with no token, session, or API key requirement |
| Risk | High — any actor can POST to `/api/v1/ai/chat` without authentication |
| Fix | Implement JWT or API key authentication before any deployment beyond localhost. |

### Issue 5 — No Secrets Committed (SAFE — for reference)

- No real API keys, passwords, or tokens appear in any committed file.
- `.env.example` contains only placeholder values (`your_ghananlp_api_key_here`, `your_gemini_api_key_here`).
- `.gitignore` is present and correctly excludes `.env`.

### Issue 6 — OpenAI API Key in Phase1 Backend (LOW RISK)

| Field | Value |
|-------|-------|
| File | `backend/services/ai_service.py` (phase1 only, not merged to main) |
| Type | Third-party credential usage |
| Detail | `OPENAI_API_KEY` env var used; no key committed |
| Risk | Low — key is via environment variable, correct pattern |
| Fix | None required for key storage. However, `ai_service.py` uses the deprecated `openai.ChatCompletion.create` API. Update to `client.chat.completions.create`. |

---

## Dependency Issues

### Flutter (`pubspec.yaml` — main branch)

| Issue | Dependency | Detail | Action |
|-------|-----------|--------|--------|
| Redundant | `http` AND `dio` | Both HTTP clients present. `AIAssistantProvider` uses `http`. `ApiClient` (phase1) uses `dio`. Only one is needed. | Remove `dio` from main until `ApiClient` is merged; or switch all HTTP to `dio`. |
| Unused in current app | `flutter_map`, `latlong2`, `geolocator`, `geocoding` | Map stack declared but no map screen exists | Keep — required for planned GeoHarvest features |
| Unused in current app | `flutter_svg`, `lottie` | No SVG/Lottie assets in repo | Keep — likely needed for production UI |
| Unused in current app | `flutter_secure_storage` | Imported but not used in any Dart file | Keep — required for future auth token storage |
| Outdated (48 packages) | Many | 48 packages have newer versions incompatible with current constraints | Schedule controlled upgrade sprint; do not upgrade blindly as breaking changes exist |
| Missing (needed for prof. branch) | `google_generative_ai`, `logger`, `sentry_flutter`, `get_it`, `equatable`, `shimmer`, `smooth_page_indicator`, `intl`, `uuid` | Required by professional-voice-ai branch but not in main `pubspec.yaml` | Add when merging that branch |
| Logger version | `logger` in prof. branch declared as `^2.4.0` | `AppLogger` uses `Level.verbose` and `Level.wtf` — these names changed in logger 2.x. `Level.verbose` → `Level.trace`, `Level.wtf` → `Level.fatal` | Fix before merging |

### Backend (`backend/requirements.txt`)

| Issue | Package | Detail | Action |
|-------|---------|--------|--------|
| Deprecated API | `openai==1.59.7` | phase1 `ai_service.py` calls `openai.ChatCompletion.create` which was removed in openai 1.0+ | Update to `client.chat.completions.create` pattern |
| Missing | `pytest` | `test_endpoints.py` uses `pytest` but it is not in `requirements.txt` | Add `pytest>=8.0.0` and `httpx` to a `requirements-dev.txt` |
| Missing | `python-dotenv` | Listed but `.env` loading not called in `main.py` | Add `load_dotenv()` call to `main.py` or remove from requirements |

---

## Test Results

### Flutter Tests (`test/widget_test.dart`)

| Test | Result | Error |
|------|--------|-------|
| `GeoHarvest app launches` | **FAIL** | `No Directionality widget found` — `AIAssistantScreen` is mounted directly without a `MaterialApp` wrapper. The `Scaffold` inside `AIAssistantPage` requires a `Directionality` ancestor. |

**Root Cause:** `tester.pumpWidget(const AIAssistantScreen())` does not wrap the widget in `MaterialApp`. The correct test setup is:
```dart
await tester.pumpWidget(
  MaterialApp(home: const AIAssistantScreen()),
);
```

**Additional Warning:** `HttpClient` warning in test output — `AIAssistantProvider` creates an `http.Client` in `GhanaNLPProvider` during initialization. Tests should inject a mock HTTP client.

**Test Coverage:** 1 test total. No unit tests. No integration tests on main. Backend has 5 tests in phase1.

### Backend Tests (`backend/tests/test_endpoints.py` — phase1 only, not in main)

| Test | Status | Notes |
|------|--------|-------|
| `test_root` | Would PASS | Checks `APP_NAME` in response — matches |
| `test_health` | **Would FAIL** | Asserts `"use_mock_services"` key exists in health response. Current `main.py` `/health` endpoint returns `ghananlp_configured` and `openai_configured` but NOT `use_mock_services`. |
| `test_chat_fallback` | Would PASS | Basic chat call succeeds |
| `test_voice_invalid_base64` | Would PASS | 400 error for bad base64 |
| `test_voice_empty_audio` | Would PASS | 400 error for empty bytes |
| `test_tool_execution_mock_price` | Would PASS | Chat returns 200 with expected keys |

---

## GeoHarvest Feature Status

| Feature | Status | Notes |
|---------|--------|-------|
| Farmer registration | NOT IMPLEMENTED | No model, no endpoint, no UI |
| Farmer profile | NOT IMPLEMENTED | No model, no endpoint, no UI |
| Produce listing | NOT IMPLEMENTED | No model, no endpoint, no UI |
| Inventory management | NOT IMPLEMENTED | — |
| Buyer registration | NOT IMPLEMENTED | — |
| Buyer discovery | DEMO ONLY | Mock buyer returned by `tool_registry.py` |
| Market prices | DEMO ONLY | Mock price 250 GHS/kg from tool registry |
| Orders | NOT IMPLEMENTED | Mock order tracking stub only |
| Order tracking | DEMO ONLY | Mock status "pending" from tool registry |
| Logistics | NOT IMPLEMENTED | — |
| Transport provider matching | DEMO ONLY | Mock transport from tool registry |
| Route / ETA | NOT IMPLEMENTED | — |
| Maps | NOT IMPLEMENTED | Package declared, no UI |
| Weather | DEMO ONLY | Mock 28°C from tool registry |
| Payments | NOT IMPLEMENTED | — |
| Wallet | NOT IMPLEMENTED | — |
| KYC | NOT IMPLEMENTED | — |
| Authentication | NOT IMPLEMENTED | No auth on any endpoint |
| Notifications | NOT IMPLEMENTED | — |
| Kofi AI (text) | PARTIAL | Intent detection + bilingual responses working; no real data |
| Voice input (ASR) | PARTIAL | Code complete; requires GhanaNLP API key |
| Voice output (TTS) | PARTIAL | Code complete; requires GhanaNLP API key |
| Ghanaian languages (Twi) | PARTIAL | Twi responses from KofiEngine; full ASR/TTS requires key |
| Ghanaian languages (others) | PARTIAL | Constants + detection + provider code present; not tested |
| Language auto-detection | PARTIAL | Offline heuristic working; could be improved |

---

## Recommended Files to Keep

These files form the correct foundation and should be preserved and built upon:

**Flutter**
- `lib/main.dart` — entry point (update to use new ChatScreen)
- `lib/core/constants/languages.dart` — complete Ghanaian language registry
- `lib/core/voice/voice_service.dart` — clean abstract interface
- `lib/core/voice/voice_router.dart` — clean fallback router
- `lib/core/voice/language_detector.dart` — working offline heuristic
- `lib/core/voice/providers/ghana_nlp_provider.dart` — complete GhanaNLP integration
- `lib/core/config/environment.dart` (from prof. branch) — centralized config
- `lib/core/exceptions/exceptions.dart` (from prof. branch) — typed exception hierarchy
- `lib/core/logging/app_logger.dart` (from prof. branch) — structured logging
- `lib/features/chat/presentation/pages/chat_page.dart` (from prof. branch) — best chat UI
- `lib/features/chat/presentation/pages/chat_screen.dart` (from prof. branch) — best screen wrapper
- `lib/features/chat/presentation/pages/splash_screen.dart` (from prof. branch) — splash with validation
- `lib/features/chat/presentation/widgets/error_banner.dart` (from prof. branch) — reusable
- `lib/features/chat/presentation/widgets/language_selector.dart` (from prof. branch) — interactive language selection
- `lib/features/chat/presentation/widgets/processing_indicator.dart` (from prof. branch) — reusable

**Backend**
- `backend/main.py` — KofiEngine + FastAPI (best single-file backend)
- `backend/tools/tool_registry.py` (from phase1) — correct architecture for tool dispatch
- `backend/Dockerfile` + `backend/docker-compose.yml` — keep for deployment
- `backend/requirements.txt` — keep and update

---

## Recommended Files to Merge

These files need to be combined or promoted into main:

| Source | Target | What to merge |
|--------|--------|--------------|
| `lib/features/ai_assistant/presentation/providers/ai_assistant_provider.dart` (main) | New unified provider | Keep HTTP backend call architecture |
| `lib/core/providers/ai_assistant_provider.dart` (prof. branch) | New unified provider | Bring in: AppLogger, typed exceptions, multi-language welcome, language guard, initialize() error handling |
| `lib/features/ai_assistant/domain/entities/chat_message.dart` (main) | `lib/core/domain/entities/chat_message.dart` | Keep `audioUrl` field; add Equatable from prof. branch version |
| `backend/services/ai_service.py` (phase1) | `backend/main.py` | Wire AiService into chat endpoint; fix deprecated OpenAI API |
| `backend/services/tts_service.py` (phase1) | `backend/main.py` | Make TTS available from chat/voice responses |
| `backend/tools/tool_registry.py` (phase1) | `backend/main.py` | Wire tool execution into KofiEngine |
| `backend/db/__init__.py` (phase2) | Backend | Keep scaffolding; implement with SQLModel/PostgreSQL |
| `lib/core/network/api_client.dart` (phase1) | Main Flutter | Use as the single HTTP client; remove raw `http` calls |

---

## Recommended Files to Remove Later

These files should be removed after their better replacements are wired up and tested:

- `lib/features/ai_assistant/presentation/pages/ai_assistant_page.dart` — replaced by `features/chat/presentation/pages/chat_page.dart`
- `lib/features/ai_assistant/presentation/pages/ai_assistant_screen.dart` — replaced by `features/chat/presentation/pages/chat_screen.dart`
- `lib/features/ai_assistant/presentation/widgets/chat_bubble.dart` — duplicate of `features/chat/presentation/widgets/chat_bubble.dart`
- `lib/features/ai_assistant/presentation/widgets/message_input.dart` — duplicate of `features/chat/presentation/widgets/message_input.dart`
- `lib/features/ai_assistant/presentation/widgets/mic_button.dart` — duplicate of `features/chat/presentation/widgets/mic_button.dart`
- `lib/features/ai_assistant/domain/entities/chat_message.dart` — replace with merged entity at `lib/core/domain/`
- `lib/features/ai_assistant/presentation/providers/ai_assistant_provider.dart` — replace with merged provider
- `lib/core/providers/ai_assistant_provider.dart` (prof. branch) — replace with merged provider
- `lib/core/ai/gemini_ai_provider.dart` — Gemini should be invoked server-side, not from Flutter client; move to backend

---

## Best Foundation

The recommended starting point for the unified GeoHarvest codebase is **main branch** as the base, with cherry-picked components from the other three branches:

| Layer | Take from | Why |
|-------|-----------|-----|
| Flutter architecture | main | Clean provider pattern, correct backend integration |
| Flutter UI (chat) | feat/professional-voice-ai | StatefulWidget, auto-scroll, language selector, cancel button, error banner |
| Flutter config | feat/professional-voice-ai | Centralized `Environment` class |
| Flutter exceptions | feat/professional-voice-ai | Typed exception hierarchy |
| Flutter logging | feat/professional-voice-ai | Structured `AppLogger` |
| Flutter ChatMessage | feat/professional-voice-ai | Equatable version |
| Flutter API client | feature/kofi/phase1 | `ApiClient` with Dio — cleaner than raw http |
| Backend FastAPI core | main | KofiEngine + routes well-structured |
| Backend services | feature/kofi/phase1 | `ai_service.py`, `tts_service.py`, `tool_registry.py` |
| Backend DB | feature/kofi/phase2 | Scaffolding to build on |

The **professional-voice-ai** branch should NOT be merged as-is — its `main.dart` doesn't wire to the new UI, `resetConversation` has a `late final` reassignment bug, the logger uses deprecated level names, and Gemini should run server-side.

---

## Recommended Final Architecture

```
User (voice or text)
  │
  ▼
Flutter App
  ├── SplashScreen (environment validation)
  └── ChatScreen
       └── ChangeNotifierProvider<AIAssistantProvider>
            └── ChatPage (StatefulWidget, auto-scroll)
                 ├── ChatBubble × n
                 ├── LanguageSelector
                 ├── MicButton → startListening / stopListening
                 └── MessageInput → processTextInput

AIAssistantProvider
  ├── ApiClient (Dio) → FastAPI backend
  └── VoiceRouter
       └── GhanaNLPProvider → GhanaNLP API
            ├── ASR (audio → text)
            ├── TTS (text → audio)
            └── Translation

                     │ HTTPS
                     ▼

FastAPI (backend)
  ├── Auth middleware (JWT)
  ├── POST /api/v1/ai/chat
  │    └── AiService
  │         ├── Gemini / GPT-4 (LLM orchestration)
  │         └── KofiEngine (fallback, no LLM needed)
  ├── POST /api/v1/ai/voice
  │    ├── GhanaNLP ASR (transcription)
  │    └── AiService
  └── Tool dispatch via ToolRegistry
       ├── MarketPriceService → GeoHarvest Market API
       ├── BuyerService → GeoHarvest Buyer Registry
       ├── TransportService → GeoHarvest Logistics API
       ├── WeatherService → Ghana Met Office / Open-Meteo
       └── OrderService → GeoHarvest Order API

PostgreSQL / PostGIS
  ├── farmers
  ├── buyers
  ├── produce_listings
  ├── orders
  ├── transactions
  ├── transport_providers
  └── conversations (persistent history)
```

---

## Implementation Roadmap

### Phase 1 — Fix and Unify (1–2 weeks)

1. Fix the widget test — wrap `AIAssistantScreen` in `MaterialApp` in `test/widget_test.dart`
2. Fix the 3 unused import warnings in `ai_assistant_page.dart` and `ai_assistant_provider.dart`
3. Wire `main.dart` to use `ChatScreen` (not `AIAssistantScreen`)
4. Add named routes to `MaterialApp` so `SplashScreen` can navigate to `/chat`
5. Fix `AppLogger` — rename `Level.verbose` → `Level.trace` and `Level.wtf` → `Level.fatal`
6. Fix `GeminiAIProvider.resetConversation` — remove `late final` constraint or use a nullable field
7. Fix `test_health` backend test — add `use_mock_services` key to health endpoint or fix the assertion
8. Fix `ai_service.py` — update from deprecated `openai.ChatCompletion.create` to `client.chat.completions.create`
9. Add `pytest` to `requirements-dev.txt`

### Phase 2 — Consolidate Branches (2–3 weeks)

1. Create unified `ChatMessage` entity at `lib/core/domain/entities/chat_message.dart`
2. Merge provider: keep HTTP backend calls + add AppLogger + typed exceptions from prof. branch
3. Bring `ApiClient` (Dio) into main; remove raw `http` package
4. Merge `ai_service.py`, `tts_service.py`, `tool_registry.py` into backend
5. Add `CORS_ORIGINS` environment variable to backend
6. Add API key authentication middleware to backend
7. Move `GHANANLP_API_KEY` to backend-only; Flutter calls backend for ASR/TTS

### Phase 3 — Real Services (4–8 weeks)

1. PostgreSQL/PostGIS schema: farmers, buyers, produce, orders, conversations
2. Replace in-memory conversation store with DB
3. Wire real market price API
4. Wire real weather API (Open-Meteo, Ghana Met)
5. Implement farmer/buyer registration and authentication
6. Implement produce listing and inventory
7. Implement order creation and tracking
8. Implement logistics and transport matching

### Phase 4 — Production Hardening (2–3 weeks)

1. HTTPS enforcement across all environments
2. Rate limiting on voice/chat endpoints
3. Sentry error monitoring (already declared in prof. branch pubspec)
4. Update all 48 outdated Flutter packages
5. Expand test suite: unit tests for KofiEngine intents, provider state machine, language detector
6. Add integration tests for backend endpoints

---

## Critical Risks

### Risk 1 — No Authentication (CRITICAL)

The backend exposes all endpoints publicly with no auth. Any IP address can send unlimited chat and voice requests, consuming GhanaNLP API quota and (when wired) AI inference credits. **Block production deployment until auth middleware is in place.**

### Risk 2 — Branch Divergence Getting Worse (HIGH)

Four branches are diverging in parallel. The professional-voice-ai branch has already introduced duplicate files at different paths. The longer these branches remain unmerged, the harder the integration will be. **Establish a single integration branch immediately.**

### Risk 3 — Gemini API Key in Flutter Binary (MEDIUM)

When the prof. branch approach is used with `--dart-define=GEMINI_API_KEY=...`, the key is compiled into the app binary and can be extracted. **Proxy all LLM calls through the backend.**

### Risk 4 — GhanaNLP API Key Single Point of Failure (MEDIUM)

Both ASR and TTS depend on the single GhanaNLP API. If the key expires or is rate-limited, all voice functionality stops. **Add a fallback ASR (e.g., Whisper via OpenAI) and consider caching common TTS audio.**

### Risk 5 — AI Commit Message in History (LOW)

Commit `e92a028` contains internal AI reasoning as its message. This is publicly visible on GitHub and unprofessional. It cannot be removed without rewriting history (which would affect phase1, phase2). **Document it and move on; or agree as a team to rebase phase1 before final merge to main.**

### Risk 6 — 48 Outdated Flutter Dependencies (MEDIUM)

Several packages with major version jumps (e.g., `record` 5 → 7, `geolocator` 10 → 14, `flutter_secure_storage` 9 → 11) contain breaking API changes. A bulk upgrade without testing could break the app. **Plan an upgrade sprint with regression testing.**

---

*End of Audit Report*

**Audit performed on branch:** `main` (commit `2a30083`)  
**Date:** 2026-08-30  
**No files were modified, deleted, committed, merged, or pushed during this audit.**
