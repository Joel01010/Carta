import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Carta environment configuration — all values loaded from assets/.env via flutter_dotenv.
/// NEVER hardcode secrets here.
class AppConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get powersyncUrl => dotenv.env['POWERSYNC_URL'] ?? '';
  static String get backendUrl => dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8000';
}
