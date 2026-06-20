import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Brand logo. The mascot image is framed in a soft "badge" (squircle with a
/// lime gradient, ring and glow) so it reads as a designed mark rather than a
/// bare floating cutout. Set [withText] to show the DoDoo wordmark beneath it.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64, this.withText = false});

  final double size;
  final bool withText;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBFCEB), Color(0xFFF2F5A0)],
        ),
        borderRadius: BorderRadius.circular(size * 0.30),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLight.withValues(alpha: 0.40),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.10),
      child: Image.asset(
        'assets/images/dodoo_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _FallbackMark(size: size),
      ),
    );

    if (!withText) return badge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        SizedBox(height: size * 0.18),
        ShaderMask(
          shaderCallback: (r) => AppGradients.primary.createShader(r),
          child: Text(
            'DoDoo',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Text(
          'Anything for you',
          style: TextStyle(
            fontSize: size * 0.135,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Shown only if the asset is missing — a simple lime "D" tile.
class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'D',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: size * 0.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
