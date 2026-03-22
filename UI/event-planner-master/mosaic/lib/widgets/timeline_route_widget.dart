import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/itinerary_card.dart';

/// Timeline/Route widget connecting itinerary stops with a neon-blue line.
class TimelineRouteWidget extends StatelessWidget {
  final List<ItineraryItem> items;
  const TimelineRouteWidget({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(left: 20, bottom: 12),
        child: Text("Tonight's Route",
            style: TextStyle(
              color: AppColors.neonBlue,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 1.2,
            )),
      ),
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        itemBuilder: (ctx, i) =>
            _TimelineStop(item: items[i], isLast: i == items.length - 1, index: i),
      ),
    ]);
  }
}

class _TimelineStop extends StatelessWidget {
  final ItineraryItem item;
  final bool isLast;
  final int index;

  const _TimelineStop({
    required this.item,
    required this.isLast,
    required this.index,
  });

  Color get _dotColor {
    // Alternate between neonBlue and deepBlue
    return index.isEven ? AppColors.neonBlue : AppColors.deepBlue;
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 36,
          child: Column(children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _dotColor.withValues(alpha: 0.15),
                border: Border.all(color: _dotColor, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: _dotColor.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 1),
                ],
              ),
              child: Center(
                child: Text('${index + 1}',
                    style: TextStyle(
                        color: _dotColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _dotColor,
                        AppColors.deepBlue.withValues(alpha: 0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                          color: _dotColor.withValues(alpha: 0.4),
                          blurRadius: 6),
                    ],
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.surfaceBorder,
                  width: 1,
                ),
              ),
              child: Row(children: [
                Text(item.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(item.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                        if (item.isVerified)
                          const Icon(Icons.verified_user_rounded,
                              size: 14, color: AppColors.neonBlue),
                      ]),
                      const SizedBox(height: 3),
                      Text('${item.time} · ${item.location}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          )),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
