# Carta — AI-Powered Evening Planner for Indian Cities

Carta is a hyper-local evening planner that uses Gemini AI to create personalized itineraries based on your mood, budget, and location. Built with a FastAPI + LangGraph backend and a Flutter frontend with offline-first sync via PowerSync.

## Architecture

```
┌─────────────┐     ┌──────────────────────────────────────┐     ┌───────────┐
│  Flutter App │────▶│  FastAPI Backend (LangGraph Pipeline) │────▶│  Supabase │
│  (Dart)      │◀────│                                      │     │  (Postgres)│
└──────┬───────┘     │  intent_parser → event_search ─┐     │     └───────────┘
       │             │                   map_scraper ──┤     │
       │             │                                 ▼     │
       │             │               planner → profile_updater│
       ▼             └──────────────────────────────────────┘
  ┌──────────┐
  │ PowerSync│  (offline-first sync)
  └──────────┘
```

## Backend Setup

### Prerequisites
- Python 3.11+
- A Supabase project with the migration applied
- Google AI (Gemini) API key

### Environment Variables

Create `carta_backend/.env`:

```env
# Required (crash if missing)
GOOGLE_API_KEY=your_gemini_api_key
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your_service_role_key

# Optional (warn if missing, features disabled gracefully)
PREDICTHQ_API_KEY=your_key
TICKETMASTER_API_KEY=your_key
SERPER_API_KEY=your_key
OPENROUTESERVICE_API_KEY=your_key

# Optional
SUPABASE_DB_URL=postgresql://...
POWERSYNC_URL=https://...
RAILWAY_PORT=8000
```

### Run

```bash
cd carta_backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check (Supabase + Gemini connectivity) |
| `POST` | `/api/chat` | Send message → get AI itinerary |
| `POST` | `/api/rate` | Rate a stop (liked/skipped) |
| `GET` | `/api/profile/{user_id}` | Get user profile |

### API Contract

`POST /api/chat` always returns HTTP 200:
```json
{
  "reply": "string",
  "itinerary": { "title": "...", "stops": [...] } | null
}
```
Never returns 500. Missing `user_id` returns 400.

### LangGraph Pipeline

```
START → intent_parser (Gemini 2.5 Flash)
      → [event_search, map_scraper] (parallel fan-out)
      → planner (Gemini 2.5 Flash with fallback chain)
      → profile_updater
      → END
```

**Model fallback chain:** gemini-2.5-flash → gemini-2.0-flash → gemini-2.0-flash-lite

**Data sources:**
- PredictHQ (events)
- Ticketmaster (events)
- Overpass API (restaurants, attractions, fuel — free, no key)
- Serper (web context enrichment)

### Tests

```bash
cd carta_backend
python -m pytest tests/ -v
```

## Flutter Setup

### Prerequisites
- Flutter 3.x
- Android SDK or iOS toolchain

### Environment Variables

Create `UI/event-planner-master/mosaic/assets/.env`:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key
POWERSYNC_URL=https://your-powersync-url
BACKEND_URL=http://10.0.2.2:8000
```

> `10.0.2.2` is the Android emulator's alias for host `localhost`.
> For physical device, use your machine's LAN IP.

### Run

```bash
cd UI/event-planner-master/mosaic
flutter pub get
flutter run
```

### App Flow

1. **Login** → Email/password, sign up, or continue as guest
2. **Onboarding** → Set city, cuisines, event preferences, budget
3. **Chat** → Tell Carta what you want (e.g., "Plan Saturday evening, budget ₹1500, I love biryani")
4. **My Plan** → View saved itineraries with timeline
5. **Wallet** → Track booking statuses

### Offline-First

The app uses PowerSync for local-first sync. If PowerSync is unavailable, screens fall back to direct Supabase REST queries. The app works in airplane mode for previously synced data.

## Database

Apply the migration in `carta_backend/supabase_migration.sql` to your Supabase project.

Key tables:
- `user_profiles` — city, cuisines, event types, budget, distance preferences
- `itineraries` — generated plans with title, date, cost estimate
- `itinerary_stops` — individual stops with time, type, location, cost
- `booking_status` — external booking tracking
- `cached_places` — cached venue data from Overpass/Serper

## Security Notes

- The Flutter app uses the **anon key** (safe for client-side)
- The backend uses the **service role key** (server-side only)
- User messages are hashed in logs (never plaintext)
- Rate limiting: 10 requests per user per minute
- Input sanitization before LLM calls
