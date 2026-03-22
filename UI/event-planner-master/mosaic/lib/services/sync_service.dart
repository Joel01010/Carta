import 'dart:async';
import '../core/powersync_connector.dart';

/// Sync status enum representing local-first PowerSync states.
enum SyncStatus { syncing, synced, offline }

/// Sync service — listens to real PowerSync status when available,
/// falls back to a fake 2s timer in dev mode.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _current = SyncStatus.syncing;
  Timer? _initTimer;
  StreamSubscription? _psSubscription;

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get currentStatus => _current;

  /// Call once at app startup.
  void init() {
    _initTimer?.cancel();

    try {
      // Try to listen to real PowerSync status
      _psSubscription = powersyncDatabase.statusStream.listen((status) {
        if (status.connected) {
          _emit(SyncStatus.synced);
        } else if (status.downloading || status.uploading) {
          _emit(SyncStatus.syncing);
        } else {
          _emit(SyncStatus.offline);
        }
      });
    } catch (_) {
      // PowerSync not initialised — fall back to fake timer
      _initTimer = Timer(const Duration(seconds: 2), () {
        _emit(SyncStatus.synced);
      });
    }
  }

  void _emit(SyncStatus status) {
    _current = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void dispose() {
    _initTimer?.cancel();
    _psSubscription?.cancel();
    _statusController.close();
  }
}
