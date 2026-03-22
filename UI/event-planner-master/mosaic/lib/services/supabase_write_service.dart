import 'package:flutter/foundation.dart';
import '../core/supabase_connector.dart';
import '../models/chat_response.dart';

/// Writes data to Supabase (writes are allowed directly — reads go through PowerSync).
class SupabaseWriteService {
  SupabaseWriteService._();
  static final SupabaseWriteService instance = SupabaseWriteService._();

  /// Save an itinerary + its stops to Supabase.
  /// Returns the itinerary UUID on success, null on failure.
  Future<String?> saveItinerary(String userId, ItineraryModel itinerary) async {
    try {
      // 1. Insert itinerary row
      final itinRows = await supabase
          .from('itineraries')
          .insert({
            'user_id': userId,
            'date': itinerary.date,
            'total_cost_estimate': itinerary.totalCostEstimate,
            'title': itinerary.title,
            'summary': itinerary.summary,
          })
          .select('id')
          .single();

      final itinId = itinRows['id'] as String;

      // 2. Insert all stops
      final stopRows = itinerary.stops.asMap().entries.map((entry) => {
            'itinerary_id': itinId,
            'sequence_order': entry.key,
            'time': entry.value.time,
            'stop_type': entry.value.stopType,
            'name': entry.value.name,
            'address': entry.value.address,
            'lat': entry.value.lat,
            'lng': entry.value.lng,
            'cost_estimate': entry.value.costEstimate,
            'duration_mins': entry.value.durationMins,
            'notes': entry.value.notes,
            'external_url': entry.value.externalUrl,
          });

      await supabase.from('itinerary_stops').insert(stopRows.toList());

      debugPrint('Saved itinerary $itinId with ${itinerary.stops.length} stops');
      return itinId;
    } catch (e) {
      debugPrint('SupabaseWriteService.saveItinerary error: $e');
      return null;
    }
  }

  /// Upsert user profile.
  Future<bool> saveUserProfile(Map<String, dynamic> profile) async {
    try {
      await supabase.from('user_profiles').upsert(profile);
      return true;
    } catch (e) {
      debugPrint('SupabaseWriteService.saveUserProfile error: $e');
      return false;
    }
  }
}
