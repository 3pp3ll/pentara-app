import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// ثيما بنتارا الفاتح والداكن، مبنيّان من رموز المرجع فقط (لا fromSeed).
abstract final class AppTheme {
  static ThemeData get light => _build(PentaraColors.light);
  static ThemeData get dark => _build(PentaraColors.dark);

  static ThemeData _build(PentaraColors c) {
    final isDark = c.brightness == Brightness.dark;

    // primary = goldText لا gold500: ودجتات Material تلوّن نصوصها بـ primary،
    // و gold500 محرّم على النص.
    // onPrimary: أبيض (surface الفاتح) فوق #8C6A1D، وكحلي onGold فوق #E6CF94.
    // الزر الذهبي الكبير لا يعتمد على هذا؛ يُبنى بتدرّجه و AppColors.onGold.
    // secondary ليس teal: التركواز لحلقة الشعار فقط.
    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.goldText,
      onPrimary: isDark ? AppColors.onGold : c.surface,
      secondary: c.goldLine,
      onSecondary: isDark ? AppColors.onGold : c.surface,
      error: c.danger.ink,
      onError: c.danger.bg,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      outline: c.border,
      outlineVariant: c.border,
      shadow: Colors.transparent,
      scrim: c.ink,
      surfaceTint: Colors.transparent,
      inverseSurface: c.ink,
      onInverseSurface: c.bg,
      inversePrimary: c.goldLine,
    );

    final textTheme = AppTypography.textTheme(ink: c.ink, muted: c.inkMuted);

    OutlineInputBorder fieldBorder(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: 1),
        );

    // لا fontFamily على مستوى ThemeData: لو مُرِّر لطبّقه Flutter على
    // كل TextTheme وأسقط خط العناوين ElMessiri. العائلات محمولة في الأنماط.
    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      dividerColor: c.border,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: c.surfaceSoft,
      focusColor: c.surfaceSoft,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AppTypography.title.copyWith(color: c.ink),
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size(44, 44),
          shape: const StadiumBorder(),
          textStyle: AppTypography.label,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: AppTypography.body.copyWith(color: c.inkMuted),
        labelStyle: AppTypography.label.copyWith(color: c.inkMuted),
        border: fieldBorder(c.border),
        enabledBorder: fieldBorder(c.border),
        focusedBorder: fieldBorder(c.goldLine),
        errorBorder: fieldBorder(c.danger.ink),
        focusedErrorBorder: fieldBorder(c.danger.ink),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.gold500,
        linearTrackColor: c.track,
        circularTrackColor: c.track,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.goldText,
        selectionColor: c.track,
        selectionHandleColor: c.goldLine,
      ),
      extensions: <ThemeExtension<dynamic>>[c],
    );
  }
}
