import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';

/// Global Supabase client — used for auth and write operations only.
SupabaseClient get supabase => Supabase.instance.client;

/// Initialise Supabase Flutter SDK.
///
/// Call this once in main() before initPowerSync().
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
}

/// Sign in with email/password.
Future<AuthResponse> signInWithEmail(String email, String password) {
  return supabase.auth.signInWithPassword(email: email, password: password);
}

/// Sign up with email/password.
Future<AuthResponse> signUpWithEmail(String email, String password) {
  return supabase.auth.signUp(email: email, password: password);
}

/// Sign out.
Future<void> signOut() => supabase.auth.signOut();

/// Get current user id or null.
String? get currentUserId => supabase.auth.currentUser?.id;

// ─── PowerSync Connector ─────────────────────────────────────────────────

/// Implements the PowerSync connector interface for Supabase.
class SupabaseConnector extends PowerSyncBackendConnector {
  final PowerSyncDatabase db;

  SupabaseConnector(this.db);

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final session = supabase.auth.currentSession;
    if (session == null) return null;

    return PowerSyncCredentials(
      endpoint: AppConfig.powersyncUrl,
      token: session.accessToken,
      userId: supabase.auth.currentUser?.id,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final tx = await database.getCrudBatch();
    if (tx == null) return;

    for (final op in tx.crud) {
      final table = op.table;
      final data = Map<String, dynamic>.from(op.opData ?? {});

      switch (op.op) {
        case UpdateType.put:
          data['id'] = op.id;
          await supabase.from(table).upsert(data);
          break;
        case UpdateType.patch:
          await supabase.from(table).update(data).eq('id', op.id);
          break;
        case UpdateType.delete:
          await supabase.from(table).delete().eq('id', op.id);
          break;
      }
    }

    await tx.complete();
  }
}
