import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/chat_response.dart';

/// Slide-up itinerary sheet shown when AI returns a plan.
class ItineraryBottomSheet extends StatelessWidget {
  final ItineraryModel itinerary;
  final VoidCallback onSave;
  final VoidCallback onRegenerate;

  const ItineraryBottomSheet({
    super.key,
    required this.itinerary,
    required this.onSave,
    required this.onRegenerate,
  });

  static void show(
    BuildContext context, {
    required ItineraryModel itinerary,
    required VoidCallback onSave,
    required VoidCallback onRegenerate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItineraryBottomSheet(
        itinerary: itinerary,
        onSave: onSave,
        onRegenerate: onRegenerate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.35,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: AppColors.surfaceBorder, width: 1),
            left: BorderSide(color: AppColors.surfaceBorder, width: 1),
            right: BorderSide(color: AppColors.surfaceBorder, width: 1),
          ),
        ),
        child: ListView(controller: controller, padding: const EdgeInsets.all(20), children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Text(itinerary.title,
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 4),
          Text(itinerary.summary,
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              )),
          const SizedBox(height: 10),

          // Cost badge
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('₹${itinerary.totalCostEstimate}',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  )),
            ),
            const SizedBox(width: 8),
            Text(itinerary.date,
                style: GoogleFonts.outfit(
                  color: AppColors.textSecondary, fontSize: 12)),
          ]),
          const SizedBox(height: 18),

          // Horizontal stop cards
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: itinerary.stops.length,
              itemBuilder: (_, i) => _StopCard(stop: itinerary.stops[i]),
            ),
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(children: [
            Expanded(
              child: _ActionButton(
                label: 'Save Plan',
                icon: Icons.bookmark_rounded,
                gradient: AppGradients.primaryReversed,
                onTap: () {
                  onSave();
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                label: 'Regenerate',
                icon: Icons.refresh_rounded,
                gradient: null,
                onTap: () {
                  Navigator.pop(context);
                  onRegenerate();
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  final StopModel stop;
  const _StopCard({required this.stop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(stop.emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(stop.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            )),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(stop.time,
              style: GoogleFonts.outfit(
                color: AppColors.neonBlue, fontSize: 11, fontWeight: FontWeight.w500)),
          Text('₹${stop.costEstimate}',
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary, fontSize: 11)),
        ]),
      ]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient? gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? AppColors.surfaceBorder : null,
          borderRadius: BorderRadius.circular(24),
          boxShadow: gradient != null
              ? [BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.3), blurRadius: 12)]
              : [],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              )),
        ]),
      ),
    );
  }
}
