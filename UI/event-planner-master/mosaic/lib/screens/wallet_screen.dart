import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../core/powersync_connector.dart';
import '../core/supabase_connector.dart';

// Convert a PowerSync ResultSet to List<Map<String, dynamic>>.
List<Map<String, dynamic>> _toMaps(dynamic resultSet) {
  final cols = resultSet.columnNames as List<String>;
  final List<Map<String, dynamic>> out = [];
  for (final row in resultSet.rows) {
    final map = <String, dynamic>{};
    for (var i = 0; i < cols.length; i++) {
      map[cols[i]] = row[i];
    }
    out.add(map);
  }
  return out;
}

/// Wallet screen — shows booking_status rows.
/// Uses PowerSync local SQLite when available, falls back to Supabase REST.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = currentUserId ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Wallet',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            )),
      ),
      body: isPowerSyncReady
          ? _PowerSyncWalletBody(userId: userId)
          : _SupabaseFallbackWalletBody(userId: userId),
    );
  }
}

// ---------------------------------------------------------------------------
// PowerSync path
// ---------------------------------------------------------------------------
class _PowerSyncWalletBody extends StatelessWidget {
  final String userId;
  const _PowerSyncWalletBody({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: powersyncDatabase.watch(
        "SELECT * FROM booking_status WHERE user_id = ? AND created_at >= datetime('now', '-7 days') ORDER BY created_at DESC",
        parameters: [userId],
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.neonBlue));
        }
        if (!snapshot.hasData) return const _EmptyWallet();
        final rows = _toMaps(snapshot.data);
        if (rows.isEmpty) return const _EmptyWallet();
        return _BookingList(rows: rows);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Supabase REST fallback
// ---------------------------------------------------------------------------
class _SupabaseFallbackWalletBody extends StatefulWidget {
  final String userId;
  const _SupabaseFallbackWalletBody({required this.userId});

  @override
  State<_SupabaseFallbackWalletBody> createState() => _SupabaseFallbackWalletBodyState();
}

class _SupabaseFallbackWalletBodyState extends State<_SupabaseFallbackWalletBody> {
  List<Map<String, dynamic>>? _rows;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final result = await supabase
          .from('booking_status')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _rows = List<Map<String, dynamic>>.from(result);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('WalletScreen Supabase fallback error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.neonBlue));
    }
    if (_rows == null || _rows!.isEmpty) return const _EmptyWallet();
    return _BookingList(rows: _rows!);
  }
}

// ---------------------------------------------------------------------------
// Shared booking list
// ---------------------------------------------------------------------------
class _BookingList extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _BookingList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final row = rows[i];
        final status = row['status']?.toString() ?? 'pending';
        final bookingUrl = row['external_booking_url']?.toString();
        final stopId = row['itinerary_stop_id']?.toString() ?? '';

        final statusColor = switch (status) {
          'confirmed' => AppColors.statusConfirmed,
          'cancelled' => AppColors.statusCancelled,
          _ => AppColors.statusPending,
        };

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: [
                  BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    stopId.length >= 8
                        ? 'Booking #${stopId.substring(0, 8)}'
                        : 'Booking #$stopId',
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 2),
                Text(status.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    )),
              ]),
            ),
            if (bookingUrl != null && bookingUrl.isNotEmpty)
              GestureDetector(
                onTap: () => launchUrl(Uri.parse(bookingUrl)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Open',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
          ]),
        );
      },
    );
  }
}

class _EmptyWallet extends StatelessWidget {
  const _EmptyWallet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.account_balance_wallet_rounded,
            color: AppColors.deepBlue, size: 48),
        const SizedBox(height: 16),
        Text('No bookings yet',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 8),
        Text('Booked events will appear here',
            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13)),
      ]),
    );
  }
}
