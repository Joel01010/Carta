import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../core/supabase_connector.dart';

/// Onboarding screen — collects user profile data then writes to Supabase.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _city = 'Chennai';
  double _budget = 2000;
  double _maxDistance = 15;
  final Set<String> _cuisines = {};
  final Set<String> _eventTypes = {};
  bool _saving = false;

  static const _cuisineOptions = [
    'Biryani', 'South Indian', 'Chinese', 'Italian',
    'Street Food', 'Seafood', 'Desserts', 'Japanese',
  ];
  static const _eventOptions = [
    'Concerts', 'Festivals', 'Theatre', 'Sports',
    'Exhibitions', 'Stand-up', 'Workshops', 'Nightlife',
  ];

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final uid = currentUserId;
      if (uid == null) throw Exception('Not signed in');

      await supabase.from('user_profiles').upsert({
        'user_id': uid,
        'city': _city,
        'preferred_cuisines': _cuisines.toList(),
        'liked_event_types': _eventTypes.toList(),
        'budget_max': _budget.round(),
        'max_distance_km': _maxDistance,
      });

      widget.onComplete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.statusCancelled),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 20),
            Text('Welcome to Carta',
                style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Your city, mapped for you.',
                style: GoogleFonts.outfit(
                    fontSize: 14, color: AppColors.neonBlue)),
            const SizedBox(height: 32),

            // City input
            _label('Your City'),
            const SizedBox(height: 8),
            _textField(
              initial: _city,
              onChanged: (v) => _city = v,
            ),
            const SizedBox(height: 28),

            // Cuisine chips
            _label('Favourite Cuisines'),
            const SizedBox(height: 10),
            _chipGrid(_cuisineOptions, _cuisines),
            const SizedBox(height: 28),

            // Event type chips
            _label('Event Types You Like'),
            const SizedBox(height: 10),
            _chipGrid(_eventOptions, _eventTypes),
            const SizedBox(height: 28),

            // Budget slider
            _label('Budget — ₹${_budget.round()}'),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.neonBlue,
                inactiveTrackColor: AppColors.surfaceBorder,
                thumbColor: Colors.white,
                overlayColor: AppColors.neonBlue.withValues(alpha: 0.15),
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8, elevation: 4),
              ),
              child: Slider(
                value: _budget,
                min: 500,
                max: 5000,
                divisions: 18,
                onChanged: (v) => setState(() => _budget = v),
              ),
            ),
            const SizedBox(height: 16),

            // Distance slider
            _label('Max Distance — ${_maxDistance.round()} km'),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.deepBlue,
                inactiveTrackColor: AppColors.surfaceBorder,
                thumbColor: Colors.white,
                overlayColor: AppColors.deepBlue.withValues(alpha: 0.15),
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8, elevation: 4),
              ),
              child: Slider(
                value: _maxDistance,
                min: 5,
                max: 30,
                divisions: 25,
                onChanged: (v) => setState(() => _maxDistance = v),
              ),
            ),
            const SizedBox(height: 36),

            // CTA
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryReversed,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.neonBlue.withValues(alpha: 0.35),
                        blurRadius: 16),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text("Let's Go",
                          style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ]),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: GoogleFonts.outfit(
        color: AppColors.neonBlue,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ));

  Widget _textField({required String initial, required ValueChanged<String> onChanged}) {
    return TextField(
      controller: TextEditingController(text: initial),
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      cursorColor: AppColors.neonBlue,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.neonBlue),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onChanged: onChanged,
    );
  }

  Widget _chipGrid(List<String> options, Set<String> selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return GestureDetector(
          onTap: () => setState(() {
            isSelected ? selected.remove(opt) : selected.add(opt);
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.neonBlue.withValues(alpha: 0.1)
                  : AppColors.surfaceBorder,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.neonBlue : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Text(opt,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                )),
          ),
        );
      }).toList(),
    );
  }
}
