import 'package:flutter/material.dart';

/// A subtle fade + slide-up entrance animation. Use [index] to stagger items
/// in a list so they cascade in.
class FadeIn extends StatelessWidget {
  const FadeIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 360),
    this.offsetY = 16,
  });

  final Widget child;
  final int index;
  final Duration duration;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // Small per-index delay via a longer curve start; capped so long lists
      // don't feel sluggish.
      duration: duration + Duration(milliseconds: (index.clamp(0, 8)) * 45),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * offsetY),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
