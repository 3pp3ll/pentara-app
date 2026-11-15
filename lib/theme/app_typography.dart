import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// أسماء العائلات كما صُرّح بها في pubspec.yaml.
abstract final class AppFonts {
  /// العناوين (500، 600).
  static const String heading = 'ElMessiri';

  /// النصوص (400، 500، 600).
  static const String body = 'IBMPlexSansArabic';

  /// اللاتيني والأرقام (500، 600).
  static const String latin = 'Alexandria';
}

/// بدائل رسم وقت التشغيل فقط (بلا تصريح في pubspec).
/// إن لم تتوفر على الجهاز يرجع Flutter إلى خطوط النظام.
const List<String> kFontFallback = ['Noto Sans Arabic', 'Noto Naskh Arabic'];

/// أنماط الطباعة. بلا لون: اللون يأتي من الثيم أو من copyWith.
///
/// letterSpacing = 0 صراحة في الأنماط العربية، لأن تباعد Material 3
/// الافتراضي يفكّك اتصال الحروف العربية.
/// أصغر حجم في النظام 12.
abstract final class AppTypography {
  // ---- ElMessiri 600 ----
  static const TextStyle displayXL = TextStyle(
    fontFamily: AppFonts.heading,
    fontFamilyFallback: kFontFallback,
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const TextStyle displayL = TextStyle(
    fontFamily: AppFonts.heading,
    fontFamilyFallback: kFontFallback,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const TextStyle title = TextStyle(
    fontFamily: AppFonts.heading,
    fontFamilyFallback: kFontFallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const TextStyle wordmark = TextStyle(
    fontFamily: AppFonts.heading,
    fontFamilyFallback: kFontFallback,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  // ---- IBMPlexSansArabic ----
  /// ارتفاع السطر 1.7 مضاعف لحجم الخط (لا 25.5 بكسل).
  static const TextStyle body = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: kFontFallback,
    fontSize: 15,
    height: 1.7,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: kFontFallback,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const TextStyle label = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: kFontFallback,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: kFontFallback,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  // ---- Alexandria ----
  /// المؤشرات والأسعار: أرقام غربية متساوية العرض.
  /// تُعرض لاحقاً داخل Directionality(textDirection: TextDirection.ltr).
  static const TextStyle metric = TextStyle(
    fontFamily: AppFonts.latin,
    fontFamilyFallback: kFontFallback,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// «PENTARA AI» تحت الشعار. التباعد 6 كما في المرجع.
  static const TextStyle wordmarkLatin = TextStyle(
    fontFamily: AppFonts.latin,
    fontFamilyFallback: kFontFallback,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 6,
  );

  /// ربط الأنماط بـ TextTheme حتى ترثها ودجتات Material.
  /// bodyMedium هو النمط الافتراضي لـ Text.
  static TextTheme textTheme({required Color ink, required Color muted}) {
    return TextTheme(
      displayLarge: displayXL.copyWith(color: ink),
      displayMedium: displayL.copyWith(color: ink),
      displaySmall: displayL.copyWith(color: ink),
      headlineLarge: displayL.copyWith(color: ink),
      headlineMedium: wordmark.copyWith(color: ink),
      headlineSmall: title.copyWith(color: ink),
      titleLarge: title.copyWith(color: ink),
      titleMedium: bodyStrong.copyWith(color: ink),
      titleSmall: label.copyWith(color: ink),
      bodyLarge: body.copyWith(color: ink),
      bodyMedium: body.copyWith(color: ink),
      bodySmall: caption.copyWith(color: muted),
      labelLarge: label.copyWith(color: ink),
      labelMedium: label.copyWith(color: ink),
      labelSmall: caption.copyWith(color: muted),
    );
  }
}
