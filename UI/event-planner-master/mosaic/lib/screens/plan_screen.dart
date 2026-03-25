import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../core/powersync_connector.dart';
import '../core/supabase_connector.dart';
import '../services/carta_api_service.dart';
import '../widgets/itinerary_card.dart';
import '../widgets/timeline_route_widget.dart';

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

/// My Plan screen — reads itinerary + stops from PowerSync local SQLite,
/// with fallback to direct Supabase REST when PowerSync is unavailable.
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = currentUserId ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('My Plan',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            )),
      ),
      body: isPowerSyncReady
          ? _PowerSyncPlanBody(userId: userId)
          : _SupabaseFallbackPlanBody(userId: userId),
    );
  }
}

// ---------------------------------------------------------------------------
// PowerSync path (real-time local reads)
// ---------------------------------------------------------------------------
class _PowerSyncPlanBody extends StatelessWidget {
  final String userId;
  const _PowerSyncPlanBody({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: powersyncDatabase.watch(
        "SELECT * FROM itineraries WHERE user_id = ? AND date >= date('now') ORDER BY date ASC LIMIT 1",
        parameters: [userId],
      ),
      builder: (context, itinSnapshot) {
        if (itinSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.neonBlue));
        }
        if (!itinSnapshot.hasData) return const _EmptyPlan();
        final rows = _toMaps(itinSnapshot.data);
        if (rows.isEmpty) return const _EmptyPlan();

        return _ItineraryView(
          itin: rows.first,
          userId: userId,
          useStream: true,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Supabase REST fallback (when PowerSync isn't ready)
// ---------------------------------------------------------------------------
class _SupabaseFallbackPlanBody extends StatefulWidget {
  final String userId;
  const _SupabaseFallbackPlanBody({required this.userId});

  @override
  State<_SupabaseFallbackPlanBody> createState() => _SupabaseFallbackPlanBodyState();
}

class _SupabaseFallbackPlanBodyState extends State<_SupabaseFallbackPlanBody> {
  Map<String, dynamic>? _itin;
  List<Map<String, dynamic>>? _stops;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final itinResult = await supabase
          .from('itineraries')
          .select()
          .eq('user_id', widget.userId)
          .gte('date', today)
          .order('date')
          .limit(1);

      if (itinResult.isNotEmpty) {
        final itin = itinResult.first;
        final itinId = itin['id'] as String? ?? '';

        final stopsResult = await supabase
            .from('itinerary_stops')
            .select()
            .eq('itinerary_id', itinId)
            .order('sequence_order');

        if (mounted) {
          setState(() {
            _itin = itin;
            _stops = List<Map<String, dynamic>>.from(stopsResult);
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('PlanScreen Supabase fallback error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.neonBlue));
    }
    if (_itin == null) return const _EmptyPlan();

    return _ItineraryDetailView(
      itin: _itin!,
      stops: _stops ?? [],
      userId: widget.userId,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared itinerary views
// ---------------------------------------------------------------------------
class _ItineraryView extends StatelessWidget {
  final Map<String, dynamic> itin;
  final String userId;
  final bool useStream;
  const _ItineraryView({required this.itin, required this.userId, this.useStream = false});

  @override
  Widget build(BuildContext context) {
    final itinId = itin['id'] as String? ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ItineraryHeader(itin: itin),
      const SizedBox(height: 16),
      Expanded(
        child: useStream && isPowerSyncReady
            ? StreamBuilder(
                stream: powersyncDatabase.watch(
                  'SELECT * FROM itinerary_stops WHERE itinerary_id = ? ORDER BY sequence_order ASC',
                  parameters: [itinId],
                ),
                builder: (context, stopsSnapshot) {
                  if (!stopsSnapshot.hasData) {
                    return Center(
                      child: Text('Loading stops…',
                          style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                    );
                  }
                  final stopRows = _toMaps(stopsSnapshot.data);
                  return _StopsList(stops: stopRows, userId: userId);
                },
              )
            : const Center(child: CircularProgressIndicator(color: AppColors.neonBlue)),
      ),
    ]);
  }
}

class _ItineraryDetailView extends StatelessWidget {
  final Map<String, dynamic> itin;
  final List<Map<String, dynamic>> stops;
  final String userId;
  const _ItineraryDetailView({required this.itin, required this.stops, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _ItineraryHeader(itin: itin),
      const SizedBox(height: 16),
      Expanded(child: _StopsList(stops: stops, userId: userId)),
    ]);
  }
}

class _ItineraryHeader extends StatelessWidget {
  final Map<String, dynamic> itin;
  const _ItineraryHeader({required this.itin});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        child: Text(itin['title']?.toString() ?? '',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            )),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('₹${itin['total_cost_estimate'] ?? 0}',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Text(itin['date']?.toString() ?? '',
              style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12)),
        ]),
      ),
    ]);
  }
}

class _StopsList extends StatelessWidget {
  final List<Map<String, dynamic>> stops;
  final String userId;
  const _StopsList({required this.stops, required this.userId});

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) {
      return Center(
        child: Text('No stops yet',
            style: GoogleFonts.outfit(color: AppColors.textSecondary)),
      );
    }

    final items = stops.map((r) {
      final stopType = r['stop_type']?.toString() ?? 'event';
      final emoji = switch (stopType) {
        'meal' => '🍽️',
        'event' => '🎭',
        'drinks' => '🍹',
        'fuel' => '⛽',
        _ => '📍',
      };
      return ItineraryItem(
        emoji: emoji,
        title: r['name']?.toString() ?? '',
        time: r['time']?.toString() ?? '',
        location: r['address']?.toString() ?? '',
        isSynced: true,
        category: stopType,
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Dismissible(
        key: UniqueKey(),
        confirmDismiss: (direction) async {
          if (stops.isNotEmpty) {
            final stopId = stops.first['id']?.toString() ?? '';
            final rating = direction == DismissDirection.startToEnd ? 'liked' : 'skipped';
            CartaApiService.instance.rateStop(
              userId: userId,
              stopId: stopId,
              rating: rating,
            );
          }
          return false;
        },
        child: TimelineRouteWidget(items: items),
      ),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.calendar_today_rounded, color: AppColors.deepBlue, size: 48),
          const SizedBox(height: 16),
          Text('No plans yet',
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 8),
          Text('Ask Carta to plan your weekend',
              style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13)),
        ]),
      ),
    );
  }
}
