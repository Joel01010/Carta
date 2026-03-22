import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/sync_service.dart';

/// Pill badge: "Syncing..." with blue pulse, "Offline" in grey, hidden when synced.
class LocalSyncIndicator extends StatefulWidget {
  const LocalSyncIndicator({super.key});

  @override
  State<LocalSyncIndicator> createState() => _LocalSyncIndicatorState();
}

class _LocalSyncIndicatorState extends State<LocalSyncIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: SyncService.instance.statusStream,
      initialData: SyncService.instance.currentStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? SyncStatus.offline;

        // When synced & online → show nothing (clean bar)
        if (status == SyncStatus.synced) return const SizedBox.shrink();

        final isSyncing = status == SyncStatus.syncing;
        final pillColor = isSyncing ? AppColors.neonBlue : AppColors.offline;
        final label = isSyncing ? 'Syncing...' : 'Offline';

        return AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, _) {
            final opacity = isSyncing ? _pulseAnim.value : 1.0;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: pillColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: pillColor.withValues(alpha: 0.4), width: 1),
                boxShadow: isSyncing
                    ? [
                        BoxShadow(
                          color: AppColors.neonBlue
                              .withValues(alpha: 0.3 * opacity),
                          blurRadius: 10,
                        )
                      ]
                    : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pillColor.withValues(alpha: opacity),
                  ),
                ),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                      color: pillColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    )),
              ]),
            );
          },
        );
      },
    );
  }
}
