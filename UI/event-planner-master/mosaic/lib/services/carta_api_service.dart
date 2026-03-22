import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../models/chat_response.dart';

/// Exception thrown when a Carta backend call fails.
class CartaApiException implements Exception {
  final String message;
  final int? statusCode;
  const CartaApiException(this.message, {this.statusCode});
  @override
  String toString() => 'CartaApiException: $message';
}

/// Single HTTP service for all Carta backend calls.
class CartaApiService {
  CartaApiService._();
  static final CartaApiService instance = CartaApiService._();

  final _client = http.Client();
  String get _base => AppConfig.backendUrl;

  /// POST /api/chat — 60s timeout (LangGraph pipeline is slow).
  Future<ChatResponse> sendChat({
    required String userId,
    required String message,
    Map<String, dynamic>? previousItinerary,
  }) async {
    final uri = Uri.parse('$_base/api/chat');
    try {
      final resp = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'message': message,
              if (previousItinerary != null)
                'previous_itinerary': previousItinerary,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode != 200) {
        throw CartaApiException(
          'Server error: ${resp.body}',
          statusCode: resp.statusCode,
        );
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return ChatResponse.fromJson(json);
    } on TimeoutException {
      throw const CartaApiException('Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      throw CartaApiException('Network error: ${e.message}');
    }
  }

  /// POST /api/rate — fire-and-forget, logs errors silently.
  Future<bool> rateStop({
    required String userId,
    required String stopId,
    required String rating,
  }) async {
    final uri = Uri.parse('$_base/api/rate');
    try {
      final resp = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'stop_id': stopId,
          'rating': rating,
        }),
      );
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('CartaApiService.rateStop error: $e');
      return false;
    }
  }

  /// GET /api/profile/{userId}
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final uri = Uri.parse('$_base/api/profile/$userId');
    try {
      final resp = await _client.get(uri);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('CartaApiService.getProfile error: $e');
      return null;
    }
  }
}
