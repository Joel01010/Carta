import 'dart:math';
import 'package:flutter/material.dart';

/// Animated Particle-Mesh Sphere — the interactive centerpiece of Carta.
///
/// Uses fibonacci-distributed 3D points projected with perspective.
/// At rest: deep blue → cyan. While listening: brightens to white-blue pulse.
class NeonVoiceOrb extends StatefulWidget {
  final bool isListening;
  final VoidCallback? onTap;

  const NeonVoiceOrb({super.key, this.isListening = false, this.onTap});

  @override
  State<NeonVoiceOrb> createState() => _NeonVoiceOrbState();
}

class _NeonVoiceOrbState extends State<NeonVoiceOrb>
    with TickerProviderStateMixin {
  late AnimationController _rotation;
  late AnimationController _morph;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
        vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
    _morph = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
    _pulse =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void didUpdateWidget(NeonVoiceOrb old) {
    super.didUpdateWidget(old);
    if (widget.isListening && !old.isListening) {
      _pulse.repeat(reverse: true);
      _rotation.duration = const Duration(seconds: 4);
      _rotation.repeat();
    } else if (!widget.isListening && old.isListening) {
      _pulse
        ..stop()
        ..value = 0;
      _rotation.duration = const Duration(seconds: 10);
      _rotation.repeat();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    _morph.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rotation, _morph, _pulse]),
        builder: (context, _) => SizedBox(
          width: 240,
          height: 240,
          child: CustomPaint(
            painter: _SpherePainter(
              rot: _rotation.value * 2 * pi,
              morph: _morph.value * 2 * pi,
              pulse: _pulse.value,
              listening: widget.isListening,
            ),
          ),
        ),
      ),
    );
  }
}

// ── 3-D helpers ──────────────────────────────────────────────────────────────

class _Pt3 {
  final double x, y, z;
  const _Pt3(this.x, this.y, this.z);
}

class _Proj {
  final double sx, sy, depth, size;
  final Color color;
  _Proj(this.sx, this.sy, this.depth, this.size, this.color);
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _SpherePainter extends CustomPainter {
  final double rot, morph, pulse;
  final bool listening;

  static const int _n = 220;
  static const double _r = 75, _f = 350;
  static final List<_Pt3> _pts = _build();

  _SpherePainter({
    required this.rot,
    required this.morph,
    required this.pulse,
    required this.listening,
  });

  static List<_Pt3> _build() {
    final g = pi * (3 - sqrt(5));
    return List.generate(_n, (i) {
      final y = 1 - (i / (_n - 1)) * 2;
      final r = sqrt(1 - y * y);
      final t = g * i;
      return _Pt3(cos(t) * r, y, sin(t) * r);
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;

    // Ambient glow
    canvas.drawCircle(
      Offset(cx, cy),
      _r * 1.9,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFF00D4FF).withValues(alpha: listening ? 0.14 : 0.05),
          const Color(0xFF0066FF).withValues(alpha: listening ? 0.06 : 0.02),
          Colors.transparent,
        ], stops: const [
          0,
          0.55,
          1
        ]).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: _r * 1.9)),
    );

    // Project particles
    final list = <_Proj>[];
    for (final p in _pts) {
      final w = sin(p.y * 3.5 + morph) *
          cos(p.x * 2.5 + morph * .6) *
          (listening ? .28 : .14);
      final mr = 1 + w;
      var x = p.x * mr, y = p.y * mr, z = p.z * mr;

      // Y rotation
      final ca = cos(rot), sa = sin(rot);
      final rx = x * ca - z * sa, rz = x * sa + z * ca;

      // X tilt
      final tilt = sin(morph * .25) * .25;
      final ct = cos(tilt), st = sin(tilt);
      final ry = y * ct - rz * st, rz2 = y * st + rz * ct;

      final s = _f / (_f + rz2 * _r);
      final d = ((rz2 + 1.3) / 2.6).clamp(0.0, 1.0);

      Color c;
      if (listening) {
        c = Color.lerp(const Color(0xFF0066FF), const Color(0xFFAAEEFF),
                (d * .6 + pulse * .4).clamp(0.0, 1.0))!
            .withValues(alpha: (.35 + d * .65).clamp(0.0, 1.0));
      } else {
        c = Color.lerp(const Color(0xFF0066FF), const Color(0xFF00D4FF), d)!
            .withValues(alpha: (.25 + d * .55).clamp(0.0, 1.0));
      }
      list.add(
          _Proj(rx * s * _r + cx, ry * s * _r + cy, d, (1.2 + d * 2.8) * s, c));
    }

    list.sort((a, b) => a.depth.compareTo(b.depth));

    for (final pt in list) {
      if (pt.depth > .5) {
        canvas.drawCircle(
          Offset(pt.sx, pt.sy),
          pt.size * (listening ? 3.0 : 2.0),
          Paint()
            ..color = pt.color.withValues(alpha: .15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      canvas.drawCircle(Offset(pt.sx, pt.sy), pt.size, Paint()..color = pt.color);
    }

    // Outer halo ring when listening
    if (listening) {
      canvas.drawCircle(
        Offset(cx, cy),
        _r * (1.3 + pulse * .15),
        Paint()
          ..color =
              const Color(0xFF00D4FF).withValues(alpha: .08 + pulse * .07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  @override
  bool shouldRepaint(_SpherePainter old) => true;
}
