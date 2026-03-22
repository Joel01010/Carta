-- ==========================================================================
-- Carta — Supabase Database Migration
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ==========================================================================

-- -------------------------------------------------------------------------
-- 1. Custom ENUM types
-- -------------------------------------------------------------------------
CREATE TYPE stop_type_enum AS ENUM ('meal', 'event', 'drinks', 'fuel');
CREATE TYPE place_type_enum AS ENUM ('restaurant', 'attraction', 'fuel');
CREATE TYPE place_source_enum AS ENUM ('google_maps', 'serper');
CREATE TYPE booking_status_enum AS ENUM ('confirmed', 'pending', 'cancelled');

-- -------------------------------------------------------------------------
-- 2. Tables
-- -------------------------------------------------------------------------

-- user_profiles
CREATE TABLE user_profiles (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    city                TEXT NOT NULL DEFAULT 'Chennai',
    preferred_cuisines  TEXT[] DEFAULT '{}',
    liked_event_types   TEXT[] DEFAULT '{}',
    budget_max          INTEGER DEFAULT 2000,
    max_distance_km     FLOAT DEFAULT 15.0,
    home_lat            DOUBLE PRECISION,
    home_lng            DOUBLE PRECISION,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id)
);

-- itineraries
CREATE TABLE itineraries (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date                DATE NOT NULL,
    total_cost_estimate INTEGER DEFAULT 0,
    title               TEXT NOT NULL,
    summary             TEXT,
    created_at          TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_itineraries_user_date ON itineraries(user_id, date);

-- itinerary_stops
CREATE TABLE itinerary_stops (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    itinerary_id    UUID NOT NULL REFERENCES itineraries(id) ON DELETE CASCADE,
    sequence_order  INTEGER NOT NULL,
    time            TEXT NOT NULL,
    stop_type       stop_type_enum NOT NULL,
    name            TEXT NOT NULL,
    address         TEXT,
    lat             DOUBLE PRECISION,
    lng             DOUBLE PRECISION,
    cost_estimate   INTEGER DEFAULT 0,
    duration_mins   INTEGER DEFAULT 60,
    notes           TEXT,
    external_url    TEXT,
    created_at      TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_stops_itinerary ON itinerary_stops(itinerary_id);

-- cached_places
CREATE TABLE cached_places (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    itinerary_id    UUID NOT NULL REFERENCES itineraries(id) ON DELETE CASCADE,
    place_type      place_type_enum NOT NULL,
    name            TEXT NOT NULL,
    address         TEXT,
    lat             DOUBLE PRECISION,
    lng             DOUBLE PRECISION,
    rating          FLOAT,
    price_level     INTEGER,
    open_now        BOOLEAN DEFAULT false,
    source          place_source_enum NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_cached_places_itinerary ON cached_places(itinerary_id);

-- booking_status
CREATE TABLE booking_status (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    itinerary_stop_id   UUID NOT NULL REFERENCES itinerary_stops(id) ON DELETE CASCADE,
    status              booking_status_enum NOT NULL DEFAULT 'pending',
    external_booking_url TEXT,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_booking_user ON booking_status(user_id, created_at);

-- -------------------------------------------------------------------------
-- 3. Row Level Security (RLS)
-- -------------------------------------------------------------------------
ALTER TABLE user_profiles   ENABLE ROW LEVEL SECURITY;
ALTER TABLE itineraries     ENABLE ROW LEVEL SECURITY;
ALTER TABLE itinerary_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE cached_places   ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking_status  ENABLE ROW LEVEL SECURITY;

-- user_profiles
CREATE POLICY "Users can view own profile"
    ON user_profiles FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can update own profile"
    ON user_profiles FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can insert own profile"
    ON user_profiles FOR INSERT WITH CHECK (user_id = auth.uid());

-- itineraries
CREATE POLICY "Users can view own itineraries"
    ON itineraries FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Service role can insert itineraries"
    ON itineraries FOR INSERT WITH CHECK (true);

-- itinerary_stops (access through parent itinerary ownership)
CREATE POLICY "Users can view own stops"
    ON itinerary_stops FOR SELECT
    USING (itinerary_id IN (SELECT id FROM itineraries WHERE user_id = auth.uid()));
CREATE POLICY "Service role can insert stops"
    ON itinerary_stops FOR INSERT WITH CHECK (true);

-- cached_places (access through parent itinerary ownership)
CREATE POLICY "Users can view own cached places"
    ON cached_places FOR SELECT
    USING (itinerary_id IN (SELECT id FROM itineraries WHERE user_id = auth.uid()));
CREATE POLICY "Service role can insert cached places"
    ON cached_places FOR INSERT WITH CHECK (true);

-- booking_status
CREATE POLICY "Users can view own bookings"
    ON booking_status FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can update own bookings"
    ON booking_status FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Service role can insert bookings"
    ON booking_status FOR INSERT WITH CHECK (true);

-- =========================================================================
-- Done! All 5 tables created with indexes and RLS.
-- =========================================================================
