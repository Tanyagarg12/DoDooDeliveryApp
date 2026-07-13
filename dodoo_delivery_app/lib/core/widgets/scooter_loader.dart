import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Branded loading animation: a lime delivery scooter (with rider) driving
/// along a moving dashed road. Drop-in replacement for a CircularProgressIndicator.
class ScooterLoader extends StatefulWidget {
  const ScooterLoader({super.key, this.message = 'Loading…'});

  /// Optional caption shown under the scooter (null hides it).
  final String? message;

  @override
  State<ScooterLoader> createState() => _ScooterLoaderState();
}

class _ScooterLoaderState extends State<ScooterLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // Lime scooter colour.
  static const Color _lime = Color(0xFF9DC209);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 170,
          height: 110,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value; // 0..1
              final bob = math.sin(t * 2 * math.pi) * 5; // gentle bounce
              final tilt = math.sin(t * 2 * math.pi) * 0.045;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Moving dashed road.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: CustomPaint(
                      size: const Size(170, 4),
                      painter: _RoadPainter(
                        phase: t,
                        color: Colors.grey.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  // Shadow (shrinks as the scooter bounces up).
                  Positioned(
                    bottom: 22,
                    child: Container(
                      width: 60 - bob.abs() * 2,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Speed streaks behind the scooter.
                  Positioned(
                    left: 14 + ((t * 2) % 1) * 10,
                    top: 44,
                    child: Opacity(
                      opacity: 0.55 * (1 - ((t * 2) % 1)),
                      child: Container(width: 22, height: 3, color: _lime),
                    ),
                  ),
                  Positioned(
                    left: 20 + (((t * 2) + 0.5) % 1) * 10,
                    top: 58,
                    child: Opacity(
                      opacity: 0.4 * (1 - (((t * 2) + 0.5) % 1)),
                      child: Container(width: 16, height: 3, color: _lime),
                    ),
                  ),
                  // The rider + scooter.
                  Transform.translate(
                    offset: Offset(0, -22 - bob),
                    child: Transform.rotate(
                      angle: tilt,
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        size: 66,
                        color: _lime,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.message!,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const dash = 16.0;
    const gap = 12.0;
    const period = dash + gap;
    final y = size.height / 2;

    // Scroll the dashes left to sell "moving forward".
    double x = -phase * period;
    while (x < size.width) {
      final start = x.clamp(0.0, size.width);
      final end = (x + dash).clamp(0.0, size.width);
      if (end > start) {
        canvas.drawLine(Offset(start, y), Offset(end, y), paint);
      }
      x += period;
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.phase != phase;
}
