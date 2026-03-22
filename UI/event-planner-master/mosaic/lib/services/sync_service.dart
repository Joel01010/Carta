import 'dart:async';

/// Sync status enum representing local-first PowerSync states.
enum SyncStatus { syncing, synced, offline }

/// Stub service representing the PowerSync + Supabase local-first layer.
///
/// In production this would:
///  - Initialize PowerSync with your Supabase endpoint
///  - Monitor connectivity changes and DB sync events
///  - Expose a reactive stream of SyncStatus
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _current = SyncStatus.syncing;
  Timer? _initTimer;

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get currentStatus => _current;

  /// Call once at app startup. Simulates a 2-second handshake then goes synced.
  void init() {
    // Cancel any previous timer to avoid duplicates
    _initTimer?.cancel();
    _initTimer = Timer(const Duration(seconds: 2), () {
      _emit(SyncStatus.synced);
    });
  }

  /// Simulate going offline.
  void simulateOffline() => _emit(SyncStatus.offline);

  /// Simulate coming back online.
  void simulateOnline() => _emit(SyncStatus.synced);

  void _emit(SyncStatus status) {
    _current = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void dispose() {
    _initTimer?.cancel();
    _statusController.close();
  }
}
