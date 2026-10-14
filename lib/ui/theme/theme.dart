import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.gold,
    onPrimary: Color(0xFF231A05),
    secondary: Palette.violet,
    onSecondary: Colors.white,
    surface: Palette.surface,
    onSurface: Palette.text,
    error: Palette.danger,
    onError: Colors.white,
    outline: Palette.border,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: Palette.background,
  );

  final text = base.textTheme.apply(
    bodyColor: Palette.text,
    displayColor: Palette.text,
  );

  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(color: Palette.text),
      bodySmall: text.bodySmall?.copyWith(color: Palette.textDim),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.background,
      foregroundColor: Palette.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Palette.text,
      ),
    ),
    cardTheme: const CardThemeData(
      color: Palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: Palette.border, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.gold,
        foregroundColor: const Color(0xFF231A05),
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.text,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: Palette.border),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.gold,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.surfaceHigh,
      labelStyle: const TextStyle(color: Palette.textDim),
      hintStyle: const TextStyle(color: Palette.textFaint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: const BorderSide(color: Palette.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: const BorderSide(color: Palette.danger),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.backgroundDeep,
      indicatorColor: Palette.gold.withValues(alpha: 0.18),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? Palette.gold
              : Palette.textDim,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Palette.surfaceHigh,
      selectedColor: Palette.gold.withValues(alpha: 0.22),
      side: const BorderSide(color: Palette.border),
      labelStyle: const TextStyle(fontFamily: fontFamily, color: Palette.text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.surfaceHigh,
      contentTextStyle: TextStyle(fontFamily: fontFamily, color: Palette.text),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: Palette.gold,
      thumbColor: Palette.gold,
      inactiveTrackColor: Palette.border,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? Palette.gold : Palette.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Palette.gold.withValues(alpha: 0.35)
            : Palette.surfaceHigh,
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
