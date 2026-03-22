import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Itinerary data model for event cards.
class ItineraryItem {
  final String emoji;
  final String title;
  final String time;
  final String location;
  final bool isVerified;
  final bool isSynced;
  final String category;

  const ItineraryItem({
    required this.emoji,
    required this.title,
    required this.time,
    required this.location,
    this.isVerified = true,
    this.isSynced = true,
    this.category = 'all',
  });
}

/// Dark-navy card with left neon-blue accent, draggable to Daily Plan.
class ItineraryCard extends StatelessWidget {
  final ItineraryItem item;
  const ItineraryCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final card = _CardContent(item: item);
    return LongPressDraggable<ItineraryItem>(
      data: item,
      delay: const Duration(milliseconds: 300),
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: Transform.scale(
            scale: 1.04,
            child: _CardContent(item: item, isDragging: true),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

class _CardContent extends StatelessWidget {
  final ItineraryItem item;
  final bool isDragging;
  const _CardContent({required this.item, this.isDragging = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      margin: const EdgeInsets.only(right: 14, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(
            color: isDragging ? AppColors.neonBlue : AppColors.neonBlue,
            width: 2,
          ),
          top: BorderSide(color: AppColors.surfaceBorder, width: 1),
          right: BorderSide(color: AppColors.surfaceBorder, width: 1),
          bottom: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
        boxShadow: [
          if (isDragging)
            BoxShadow(
              color: AppColors.neonBlue.withValues(alpha: 0.15),
              blurRadius: 28,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 26)),
                  Row(children: [
                    if (item.isSynced) _SyncBadge(synced: item.isSynced),
                    if (item.isVerified) ...[
                      const SizedBox(width: 6),
                      _VerifiedBadge(),
                    ],
                  ]),
                ],
              ),
              const SizedBox(height: 10),
              Text(item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  )),
              const SizedBox(height: 6),
              Text(item.time,
                  style: const TextStyle(
                    color: AppColors.neonBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 4),
              Text(item.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  )),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.drag_indicator_rounded,
                      size: 14, color: AppColors.textSecondary),
                  SizedBox(width: 3),
                  Text('hold to drag',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  final bool synced;
  const _SyncBadge({required this.synced});

  @override
  Widget build(BuildContext context) {
    final color = synced ? AppColors.neonBlue : AppColors.offline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(synced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            size: 10, color: color),
        const SizedBox(width: 3),
        Text(synced ? 'Synced' : 'Local',
            style: TextStyle(
                fontSize: 9, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ticket verified',
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neonBlue.withValues(alpha: 0.5)),
      ),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.neonBlue.withValues(alpha: 0.12),
          boxShadow: [
            BoxShadow(
                color: AppColors.neonBlue.withValues(alpha: 0.4),
                blurRadius: 8),
          ],
        ),
        child: const Icon(Icons.verified_user_rounded,
            size: 14, color: AppColors.neonBlue),
      ),
    );
  }
}
