import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Glassmorphic chat input bar with neon-blue glow. No pink/purple.
class GlassInputBar extends StatefulWidget {
  final ValueChanged<String>? onSubmitted;
  const GlassInputBar({super.key, this.onSubmitted});

  @override
  State<GlassInputBar> createState() => _GlassInputBarState();
}

class _GlassInputBarState extends State<GlassInputBar> {
  final _controller = TextEditingController();
  bool _hasFocus = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSubmitted?.call(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _hasFocus
              ? AppColors.neonBlue.withValues(alpha: 0.7)
              : AppColors.surfaceBorder,
          width: 1.5,
        ),
        boxShadow: _hasFocus
            ? [
                BoxShadow(
                    color: AppColors.neonBlue.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 1),
              ]
            : [],
      ),
      child: Row(children: [
        const Icon(Icons.auto_awesome_rounded,
            color: AppColors.neonBlue, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Focus(
            onFocusChange: (f) => setState(() => _hasFocus = f),
            child: TextField(
              controller: _controller,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              cursorColor: AppColors.neonBlue,
              cursorWidth: 2,
              decoration: const InputDecoration(
                hintText: 'Ask Carta anything… or type a plan',
                hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _submit,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.primary,
              boxShadow: [
                BoxShadow(
                    color: AppColors.neonBlue.withValues(alpha: 0.4),
                    blurRadius: 12),
              ],
            ),
            child: const Icon(Icons.send_rounded,
                color: Colors.white, size: 17),
          ),
        ),
      ]),
    );
  }
}
