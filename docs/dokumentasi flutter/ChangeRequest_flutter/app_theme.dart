// Hand-written theme layer. Values come from app_tokens.dart (generated from tokens.json).
// Not compiled in this environment: run `flutter analyze` after copying into your project.
import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Locker states used across Petugas, Admin (mobile + web) and the customer web.
enum LockerState { kosong, disewa, perhatian, offline }

@immutable
class StatusStyle {
  const StatusStyle({
    required this.main,
    required this.container,
    required this.tint,
    required this.border,
    required this.text,
    required this.strong,
  });

  final Color main; // dots, big numbers, solid buttons
  final Color container; // badge / chip background
  final Color tint; // card background when highlighted
  final Color border; // card border when highlighted
  final Color text; // text on container
  final Color strong; // darkest, for hero numbers
}

abstract final class AppStatus {
  static const success = StatusStyle(
    main: AppColors.successMain,
    container: AppColors.successContainer,
    tint: AppColors.successTint,
    border: AppColors.successBorder,
    text: AppColors.successText,
    strong: AppColors.successStrong,
  );
  static const info = StatusStyle(
    main: AppColors.infoMain,
    container: AppColors.infoContainer,
    tint: AppColors.infoTint,
    border: AppColors.infoBorder,
    text: AppColors.infoText,
    strong: AppColors.infoStrong,
  );
  static const warning = StatusStyle(
    main: AppColors.warningMain,
    container: AppColors.warningContainer,
    tint: AppColors.warningTint,
    border: AppColors.warningBorder,
    text: AppColors.warningText,
    strong: AppColors.warningStrong,
  );
  static const danger = StatusStyle(
    main: AppColors.dangerMain,
    container: AppColors.dangerContainer,
    tint: AppColors.dangerTint,
    border: AppColors.dangerBorder,
    text: AppColors.dangerText,
    strong: AppColors.dangerStrong,
  );

  /// Single place that maps a locker state to its colors (mirrors semantic.state in tokens.json).
  static StatusStyle of(LockerState s) => switch (s) {
        LockerState.kosong => success,
        LockerState.disewa => info,
        LockerState.perhatian => warning,
        LockerState.offline => danger,
      };

  static String label(LockerState s) => switch (s) {
        LockerState.kosong => 'Kosong',
        LockerState.disewa => 'Disewa',
        LockerState.perhatian => 'Perhatian',
        LockerState.offline => 'Offline',
      };
}

/// Responsive helper: same widgets, different layout per width.
enum ScreenClass { compact, medium, expanded }

ScreenClass screenClassOf(double width) {
  if (width >= 1024) return ScreenClass.expanded; // admin web: sidebar + wide tables
  if (width >= 600) return ScreenClass.medium;
  return ScreenClass.compact; // petugas + admin mobile: bottom nav
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.brandPrimary,
    onPrimary: AppColors.brandOnPrimary,
    primaryContainer: AppColors.brandPrimaryContainer,
    onPrimaryContainer: AppColors.brandPrimary,
    secondary: AppColors.neutralInk,
    onSecondary: AppColors.neutralOnInverse,
    error: AppColors.dangerMain,
    onError: AppColors.neutralOnInverse,
    surface: AppColors.neutralSurface,
    onSurface: AppColors.neutralInk,
    outline: AppColors.neutralBorderStrong,
    outlineVariant: AppColors.neutralBorder,
  );

  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.neutralBg,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displayMedium: AppType.display,
      headlineMedium: AppType.headline,
      titleLarge: AppType.title,
      titleMedium: AppType.subtitle,
      bodyLarge: AppType.body,
      bodyMedium: AppType.bodySm,
      labelLarge: AppType.bodyStrong,
      bodySmall: AppType.caption,
      labelSmall: AppType.overline,
    ).apply(bodyColor: AppColors.neutralInk, displayColor: AppColors.neutralInk),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.neutralBg,
      foregroundColor: AppColors.neutralInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: AppSize.appBar,
      titleTextStyle: AppType.title,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSize.buttonLg),
        shape: buttonShape,
        textStyle: AppType.bodyStrong,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSize.buttonMd),
        shape: buttonShape,
        side: const BorderSide(color: AppColors.neutralBorderStrong),
        foregroundColor: AppColors.neutralTextBody,
        textStyle: AppType.bodyStrong,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.neutralSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s3),
      hintStyle: AppType.bodySm.copyWith(color: AppColors.neutralTextDisabled),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.neutralBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.neutralBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.neutralSurface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: AppSize.bottomNav,
      backgroundColor: AppColors.neutralSurface,
      indicatorColor: AppColors.brandPrimaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppType.overline.copyWith(
          letterSpacing: 0,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
          color: states.contains(WidgetState.selected) ? AppColors.brandPrimary : AppColors.neutralTextMuted,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.neutralBorder, thickness: 1, space: 1),
  );
}
