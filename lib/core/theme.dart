import 'package:flutter/material.dart';

const brandColor = Color(0xFF10B981);
const brandDark = Color(0xFF047857);
const incomeColor = Color(0xFF10B981);
const expenseColor = Color(0xFFF43F5E);
const warningColor = Color(0xFFF59E0B);
const accentGold = Color(0xFFFBBF24);

const _lightBg = Color(0xFFF8FAFC);
const _darkBg = Color(0xFF0F172A);
const _darkSurface = Color(0xFF1E293B);

const cardRadius = 20.0;

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: brandColor,
    brightness: brightness,
    primary: dark ? const Color(0xFF34D399) : brandColor,
    surface: dark ? _darkSurface : Colors.white,
    error: expenseColor,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  // Diqqat: base.textTheme da o'lchamlar yo'q (ular Theme.of da qo'shiladi), shuning uchun
  // fontSize har doim aniq beriladi; shrift oilasi esa shu yerdan meros olinadi.
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: dark ? Colors.white12 : const Color(0xFFE2E8F0)),
  );

  return base.copyWith(
    scaffoldBackgroundColor: dark ? _darkBg : _lightBg,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? _darkBg : _lightBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF0B1324) : Colors.white,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: scheme.primary, width: 2)),
      errorBorder: border.copyWith(borderSide: const BorderSide(color: expenseColor)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? _darkSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      showDragHandle: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? _darkSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: brandColor.withValues(alpha: 0.16),
      labelTextStyle: WidgetStatePropertyAll(base.textTheme.labelSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: base.textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}

/// Kartochkalar uchun yumshoq soya.
List<BoxShadow> softShadow(BuildContext context) => Theme.of(context).brightness == Brightness.dark
    ? const []
    : [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
