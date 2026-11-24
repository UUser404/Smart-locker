import 'package:flutter/painting.dart';

abstract final class AppColors {
  static const brandPrimary = Color(0xFF1D4ED8);
  static const brandPrimaryContainer = Color(0xFFDBEAFE);
  static const brandOnPrimary = Color(0xFFFFFFFF);
  static const neutralBg = Color(0xFFF5F7FA);
  static const neutralSurface = Color(0xFFFFFFFF);
  static const neutralSurfaceMuted = Color(0xFFF8FAFC);
  static const neutralFillMuted = Color(0xFFF1F5F9);
  static const neutralBorder = Color(0xFFE2E8F0);
  static const neutralBorderStrong = Color(0xFFCBD5E1);
  static const neutralInk = Color(0xFF0F172A);
  static const neutralTextBody = Color(0xFF475569);
  static const neutralTextMuted = Color(0xFF64748B);
  static const neutralTextDisabled = Color(0xFF94A3B8);
  static const neutralInverse = Color(0xFF0F172A);
  static const neutralInverseRaised = Color(0xFF1E293B);
  static const neutralOnInverse = Color(0xFFFFFFFF);
  static const neutralOnInverseMuted = Color(0xFFCBD5E1);
  static const successMain = Color(0xFF16A34A);
  static const successContainer = Color(0xFFDCFCE7);
  static const successTint = Color(0xFFF0FDF4);
  static const successBorder = Color(0xFFBBF7D0);
  static const successText = Color(0xFF166534);
  static const successStrong = Color(0xFF14532D);
  static const infoMain = Color(0xFF2563EB);
  static const infoContainer = Color(0xFFDBEAFE);
  static const infoTint = Color(0xFFEFF6FF);
  static const infoBorder = Color(0xFFBFDBFE);
  static const infoText = Color(0xFF1D4ED8);
  static const infoStrong = Color(0xFF1E3A8A);
  static const warningMain = Color(0xFFEA580C);
  static const warningContainer = Color(0xFFFFEDD5);
  static const warningTint = Color(0xFFFFF7ED);
  static const warningBorder = Color(0xFFFDBA74);
  static const warningText = Color(0xFFC2410C);
  static const warningStrong = Color(0xFF9A3412);
  static const dangerMain = Color(0xFFDC2626);
  static const dangerContainer = Color(0xFFFEE2E2);
  static const dangerTint = Color(0xFFFEF2F2);
  static const dangerBorder = Color(0xFFFECACA);
  static const dangerText = Color(0xFFB91C1C);
  static const dangerStrong = Color(0xFF7F1D1D);
}

abstract final class AppSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;
}

abstract final class AppRadius {
  static const tag = 6.0;
  static const field = 12.0;
  static const button = 14.0;
  static const card = 16.0;
  static const hero = 18.0;
  static const sheet = 28.0;
  static const pill = 999.0;
}

abstract final class AppSize {
  static const touchMin = 44.0;
  static const buttonLg = 52.0;
  static const buttonMd = 44.0;
  static const buttonSm = 36.0;
  static const chip = 32.0;
  static const appBar = 56.0;
  static const bottomNav = 80.0;
  static const topbar = 64.0;
  static const sidebar = 240.0;
  static const contentMax = 1136.0;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
  static const holdToConfirm = Duration(milliseconds: 2000);
}

abstract final class AppOpacity {
  static const scrim = 0.55;
  static const disabled = 0.5;
}

abstract final class AppType {
  static const display = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.1,
  );
  static const headline = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.273,
  );
  static const title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.333,
  );
  static const subtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1.333,
  );
  static const bodyStrong = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.429,
  );
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.429,
  );
  static const bodySm = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.385,
  );
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.333,
  );
  static const overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.455,
    letterSpacing: 0.8,
  );
  static const micro = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );
}
