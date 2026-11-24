import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

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

  final Color main;
  final Color container;
  final Color tint;
  final Color border;
  final Color text;
  final Color strong;
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

  static StatusStyle of(LockerState state) => switch (state) {
    LockerState.kosong => success,
    LockerState.disewa => info,
    LockerState.perhatian => warning,
    LockerState.offline => danger,
  };

  static String label(LockerState state) => switch (state) {
    LockerState.kosong => 'Kosong',
    LockerState.disewa => 'Disewa',
    LockerState.perhatian => 'Perhatian',
    LockerState.offline => 'Offline',
  };
}

enum ScreenClass { compact, medium, expanded }

ScreenClass screenClassOf(double width) {
  if (width >= 1024) return ScreenClass.expanded;
  if (width >= 600) return ScreenClass.medium;
  return ScreenClass.compact;
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

  final textTheme = GoogleFonts.interTextTheme(
    const TextTheme(
      displayMedium: AppType.display,
      headlineMedium: AppType.headline,
      titleLarge: AppType.title,
      titleMedium: AppType.subtitle,
      bodyLarge: AppType.body,
      bodyMedium: AppType.bodySm,
      labelLarge: AppType.bodyStrong,
      bodySmall: AppType.caption,
      labelSmall: AppType.overline,
    ),
  ).apply(bodyColor: AppColors.neutralInk, displayColor: AppColors.neutralInk);

  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.neutralBg,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.neutralBg,
      foregroundColor: AppColors.neutralInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: AppSize.appBar,
      titleTextStyle: AppType.title,
    ),
    cardTheme: CardThemeData(
      color: AppColors.neutralSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.neutralBorder),
      ),
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s4,
        vertical: AppSpace.s3,
      ),
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: AppSize.bottomNav,
      backgroundColor: AppColors.neutralSurface,
      indicatorColor: AppColors.brandPrimaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppType.overline.copyWith(
          letterSpacing: 0,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? AppColors.brandPrimary
              : AppColors.neutralTextMuted,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.neutralBorder,
      thickness: 1,
      space: 1,
    ),
  );
}
