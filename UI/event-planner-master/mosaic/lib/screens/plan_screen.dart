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

/// My Plan screen — reads itinerary + stops from PowerSync local SQLite.
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
      body: StreamBuilder(
        stream: powersyncDatabase.watch(
          "SELECT * FROM itineraries WHERE user_id = ? AND date >= date('now') ORDER BY date ASC LIMIT 1",
          parameters: [userId],
        ),
        builder: (context, itinSnapshot) {
          if (itinSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.neonBlue));
          }

          if (!itinSnapshot.hasData) return _EmptyPlan();
          final rows = _toMaps(itinSnapshot.data);
          if (rows.isEmpty) return _EmptyPlan();

          final itin = rows.first;
          final itinId = itin['id'] as String? ?? '';

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
            const SizedBox(height: 16),

            Expanded(
              child: StreamBuilder(
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
                  if (stopRows.isEmpty) {
                    return Center(
                      child: Text('No stops yet',
                          style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                    );
                  }

                  final items = stopRows.map((r) {
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
                        if (stopRows.isNotEmpty) {
                          final stopId = stopRows.first['id']?.toString() ?? '';
                          final rating = direction == DismissDirection.startToEnd
                              ? 'liked'
                              : 'skipped';
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
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _EmptyPlan extends StatelessWidget {
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
