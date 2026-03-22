import 'package:powersync/powersync.dart';

/// PowerSync local-SQLite schema matching the 5 Supabase tables.
///
/// These tables are synced from Supabase via PowerSync sync rules.
/// All reads go through local SQLite — never directly to Supabase.
final schema = Schema([
  Table('user_profiles', [
    Column.text('user_id'),
    Column.text('city'),
    Column.text('preferred_cuisines'),   // stored as JSON array string
    Column.text('liked_event_types'),    // stored as JSON array string
    Column.integer('budget_max'),
    Column.real('max_distance_km'),
    Column.real('home_lat'),
    Column.real('home_lng'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),

  Table('itineraries', [
    Column.text('user_id'),
    Column.text('date'),
    Column.integer('total_cost_estimate'),
    Column.text('title'),
    Column.text('summary'),
    Column.text('created_at'),
  ]),

  Table('itinerary_stops', [
    Column.text('itinerary_id'),
    Column.integer('sequence_order'),
    Column.text('time'),
    Column.text('stop_type'),
    Column.text('name'),
    Column.text('address'),
    Column.real('lat'),
    Column.real('lng'),
    Column.integer('cost_estimate'),
    Column.integer('duration_mins'),
    Column.text('notes'),
    Column.text('external_url'),
    Column.text('created_at'),
  ]),

  Table('cached_places', [
    Column.text('itinerary_id'),
    Column.text('place_type'),
    Column.text('name'),
    Column.text('address'),
    Column.real('lat'),
    Column.real('lng'),
    Column.real('rating'),
    Column.integer('price_level'),
    Column.integer('open_now'),
    Column.text('source'),
    Column.text('created_at'),
  ]),

  Table('booking_status', [
    Column.text('user_id'),
    Column.text('itinerary_stop_id'),
    Column.text('status'),              // confirmed | pending | cancelled
    Column.text('external_booking_url'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
]);
