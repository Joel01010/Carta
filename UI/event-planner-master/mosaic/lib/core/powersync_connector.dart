import 'package:powersync/powersync.dart';
import 'package:path_provider/path_provider.dart';
import 'powersync_schema.dart';
import 'supabase_connector.dart';

/// Global PowerSync database instance — use for all local reads.
late final PowerSyncDatabase powersyncDatabase;

/// Initialise PowerSync + connect it to Supabase for sync.
///
/// Call this once in main() before runApp().
Future<void> initPowerSync() async {
  final dir = await getApplicationSupportDirectory();
  final path = '${dir.path}/carta.db';

  powersyncDatabase = PowerSyncDatabase(
    schema: schema,
    path: path,
  );

  await powersyncDatabase.initialize();

  // Connect using Supabase auth credentials
  final connector = SupabaseConnector(powersyncDatabase);
  await powersyncDatabase.connect(connector: connector);
}
