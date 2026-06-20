import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Brand palette ─────────────────────────────────────────────────────────────
// Brand colors: #D7DE26 / #D0DA31 / #BABC2F

class AppColors {
  // Brand – lime-yellow
  static const primary = Color(0xFFBABC2F);       // olive-lime (darkest, best contrast)
  static const primaryMid = Color(0xFFD0DA31);     // mid lime
  static const primaryLight = Color(0xFFD7DE26);   // bright lime
  static const primaryContainer = Color(0xFFF2F5A0); // very light lime tint
  static const onPrimary = Color(0xFF1C1D00);      // near-black text on lime
  static const onPrimaryContainer = Color(0xFF2A2D00);

  // Accent – use deep olive for dark-contrast elements
  static const accent = Color(0xFF8A8C00);         // deep olive
  static const accentContainer = Color(0xFFEBED70);

  // Rider status – kept semantic
  static const online = Color(0xFF22C55E);
  static const onlineBg = Color(0xFFDCFCE7);
  static const onlineDark = Color(0xFF16A34A);
  static const offline = Color(0xFF94A3B8);
  static const offlineBg = Color(0xFFF1F5F9);
  static const offlineDarkBg = Color(0xFF1E293B);
  static const busy = Color(0xFFF97316);
  static const busyBg = Color(0xFFFFEDD5);

  // Backgrounds – warm lime tint
  static const bgLight = Color(0xFFF6F7E8);        // warm off-white with lime tint
  static const cardLight = Colors.white;
  static const bgDark = Color(0xFF0E0F00);          // deep olive-black
  static const cardDark = Color(0xFF1A1C05);        // dark olive card
  static const surfaceDark = Color(0xFF22250A);     // slightly lighter dark olive

  // Semantic
  static const error = Color(0xFFEF4444);
  static const errorBg = Color(0xFFFEE2E2);
  static const success = Color(0xFF22C55E);

  // Amber alias (used by some widgets)
  static const amber = Color(0xFFEAB308);
  static const amberLight = Color(0xFFFBBF24);
  static const amberContainer = Color(0xFFFEF3C7);

  AppColors._();
}

// ── Gradient helpers ──────────────────────────────────────────────────────────

class AppGradients {
  // Brand gradient: olive → bright lime
  static const primary = LinearGradient(
    colors: [Color(0xFF8A8C00), Color(0xFFBABC2F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Brand gradient for dark backgrounds: bright lime → yellow-lime
  static const primaryDark = LinearGradient(
    colors: [Color(0xFFD0DA31), Color(0xFFD7DE26)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const amber = LinearGradient(
    colors: [Color(0xFFEAB308), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Lime brand splash (for headers, hero sections)
  static const brandSplash = LinearGradient(
    colors: [Color(0xFFBABC2F), Color(0xFFD7DE26)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient statusGradient(String status, bool isDark) {
    switch (status) {
      case 'online':
        return LinearGradient(
          colors: isDark
              ? [const Color(0xFF14532D), const Color(0xFF166534)]
              : [const Color(0xFF16A34A), const Color(0xFF22C55E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'busy':
        // Friendly indigo — "on a delivery", not a warning.
        return LinearGradient(
          colors: isDark
              ? [const Color(0xFF3730A3), const Color(0xFF4338CA)]
              : [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default: // offline — use brand lime
        return LinearGradient(
          colors: isDark
              ? [const Color(0xFF22250A), const Color(0xFF2E3210)]
              : [const Color(0xFF8A8C00), const Color(0xFFBABC2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  AppGradients._();
}

// ── Theme ─────────────────────────────────────────────────────────────────────

class AppTheme {
  static ThemeData light() {
    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.accent,
      secondaryContainer: AppColors.accentContainer,
      tertiary: AppColors.amber,
      tertiaryContainer: AppColors.amberContainer,
      surface: const Color(0xFFF9FAF0),
      onSurface: const Color(0xFF1A1C00),
      onSurfaceVariant: const Color(0xFF5C6000),
      outline: const Color(0xFFDDDE9E),
      error: AppColors.error,
    );
    return _build(cs, Brightness.light);
  }

  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.primaryLight,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primaryLight,
      onPrimary: AppColors.onPrimary,
      primaryContainer: const Color(0xFF3A3C00),
      onPrimaryContainer: AppColors.primaryContainer,
      secondary: AppColors.primaryMid,
      secondaryContainer: const Color(0xFF2A2D00),
      tertiary: AppColors.amberLight,
      tertiaryContainer: const Color(0xFF4A3800),
      surface: AppColors.surfaceDark,
      onSurface: const Color(0xFFF2F5A0),
      onSurfaceVariant: const Color(0xFFBBBD60),
      outline: const Color(0xFF3A3D10),
      error: const Color(0xFFF87171),
    );
    return _build(cs, Brightness.dark);
  }

  static ThemeData _build(ColorScheme cs, Brightness br) {
    final dark = br == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: br,
      scaffoldBackgroundColor: dark ? AppColors.bgDark : AppColors.bgLight,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
                .copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark
                .copyWith(statusBarColor: Colors.transparent),
      ),

      // ── Cards ───────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? AppColors.cardDark : AppColors.cardLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFD8DA8A),
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Bottom Navigation ────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: dark ? AppColors.cardDark : Colors.white,
        indicatorColor: dark
            ? AppColors.primaryLight.withValues(alpha: 0.20)
            : AppColors.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final sel = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
            color: sel ? cs.primary : cs.onSurfaceVariant,
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final sel = s.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: sel ? cs.primary : cs.onSurfaceVariant,
          );
        }),
      ),

      // ── Inputs ──────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.surfaceDark : const Color(0xFFF9FAF0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFDDDE9E),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFDDDE9E),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(
            color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            fontWeight: FontWeight.w400),
      ),

      // ── Buttons ──────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: AppColors.onPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ),

      // ── Chips ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: dark
            ? Colors.white.withValues(alpha: 0.07)
            : const Color(0xFFDDDE9E),
        thickness: 1,
        space: 1,
      ),

      // ── Bottom Sheet ─────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? AppColors.cardDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: dark
            ? AppColors.primaryLight.withValues(alpha: 0.3)
            : const Color(0xFFB8BA50),
        dragHandleSize: const Size(40, 4),
      ),

      // ── Dialog ───────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? AppColors.cardDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      // ── Snackbar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor:
            dark ? const Color(0xFF2A2D00) : const Color(0xFF1A1C00),
        contentTextStyle: const TextStyle(
            color: Color(0xFFD7DE26), fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}
