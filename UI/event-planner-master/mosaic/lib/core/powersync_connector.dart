import 'package:powersync/powersync.dart';
import 'package:path_provider/path_provider.dart';
import 'powersync_schema.dart';
import 'supabase_connector.dart';

/// Global PowerSync database instance — nullable to prevent LateInitializationError.
PowerSyncDatabase? _powersyncDb;

/// Access the PowerSync database. Throws if not yet initialized.
PowerSyncDatabase get powersyncDatabase {
  if (_powersyncDb == null) {
    throw StateError('PowerSync not initialized — use isPowerSyncReady check first');
  }
  return _powersyncDb!;
}

/// Whether PowerSync has been successfully initialized.
bool get isPowerSyncReady => _powersyncDb != null;

/// Initialise PowerSync + connect it to Supabase for sync.
///
/// Call this once in main() before runApp(). Wrapped in try/catch so
/// the app continues without sync if PowerSync setup fails.
Future<void> initPowerSync() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final path = '${dir.path}/carta.db';

    _powersyncDb = PowerSyncDatabase(
      schema: schema,
      path: path,
    );

    await _powersyncDb!.initialize();

    // Connect using Supabase auth credentials
    final connector = SupabaseConnector(_powersyncDb!);
    await _powersyncDb!.connect(connector: connector);
  } catch (e) {
    _powersyncDb = null;
    // ignore — app works without PowerSync, screens fall back to Supabase REST
  }
}
