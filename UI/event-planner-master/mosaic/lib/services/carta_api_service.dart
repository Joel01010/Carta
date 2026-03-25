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

  /// Debounce tracking — prevent duplicate rapid sends.
  DateTime? _lastSendTime;
  static const _debounceMs = 300;

  /// POST /api/chat — 60s timeout (LangGraph pipeline is slow).
  Future<ChatResponse> sendChat({
    required String userId,
    required String message,
    Map<String, dynamic>? previousItinerary,
  }) async {
    // Debounce: reject if called within 300ms of last send
    final now = DateTime.now();
    if (_lastSendTime != null &&
        now.difference(_lastSendTime!).inMilliseconds < _debounceMs) {
      throw const CartaApiException('Please wait a moment before sending again.');
    }
    _lastSendTime = now;

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

      debugPrint('POST /api/chat → ${resp.statusCode} (${resp.body.length} bytes)');

      if (resp.statusCode != 200) {
        throw CartaApiException(
          'Server error: ${resp.body}',
          statusCode: resp.statusCode,
        );
      }

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      try {
        return ChatResponse.fromJson(json);
      } catch (e) {
        debugPrint('ChatResponse parse error: $e — raw: ${resp.body.substring(0, 200)}');
        throw const CartaApiException('Received a response but couldn\'t read it.');
      }
    } on TimeoutException {
      throw const CartaApiException('Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      if (e.message.contains('Connection refused') ||
          e.message.contains('connection refused') ||
          e.message.contains('ECONNREFUSED')) {
        throw const CartaApiException("Can't reach Carta's brain. Check connection.");
      }
      throw CartaApiException('Network error: ${e.message}');
    }
  }

  /// POST /api/rate — 10s timeout, fire-and-forget.
  Future<bool> rateStop({
    required String userId,
    required String stopId,
    required String rating,
  }) async {
    final uri = Uri.parse('$_base/api/rate');
    try {
      final resp = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'stop_id': stopId,
              'rating': rating,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('CartaApiService.rateStop error: $e');
      return false;
    }
  }

  /// GET /api/profile/{userId} — 10s timeout.
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final uri = Uri.parse('$_base/api/profile/$userId');
    try {
      final resp = await _client.get(uri).timeout(const Duration(seconds: 10));
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
