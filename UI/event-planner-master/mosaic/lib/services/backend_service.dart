import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';

/// HTTP client for the Carta FastAPI backend.
class BackendService {
  BackendService._();
  static final BackendService instance = BackendService._();

  final _client = http.Client();
  String get _base => AppConfig.backendUrl;

  /// POST /api/chat — send a message, get itinerary + reply.
  ///
  /// Returns the decoded JSON body:
  /// { "reply_text": "...", "itinerary": { ... } | null }
  Future<Map<String, dynamic>> chat({
    required String userId,
    required String message,
    Map<String, dynamic>? previousItinerary,
  }) async {
    final uri = Uri.parse('$_base/api/chat');
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'message': message,
        if (previousItinerary != null) 'previous_itinerary': previousItinerary,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Backend /api/chat error ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// POST /api/rate — rate a stop.
  Future<void> rate({
    required String userId,
    required String stopId,
    required String rating, // "liked" | "skipped"
  }) async {
    final uri = Uri.parse('$_base/api/rate');
    final resp = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'stop_id': stopId,
        'rating': rating,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Backend /api/rate error ${resp.statusCode}');
    }
  }
}
