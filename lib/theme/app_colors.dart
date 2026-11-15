import 'package:flutter/material.dart';

/// ألوان بنتارا. مصدرها الوحيد جدول المرجع؛ لا ألوان خارجه.
///
/// قاعدة: لا يُربط رمزان ببعضهما ولو تطابقت القيمة اليوم.
/// مثال: goldText الفاتح = goldDeep رقماً، لكن كلاً منهما مكتوب مستقلاً.

// ---------------------------------------------------------------------------
// ثوابت لا تتبدّل بين الوضعين
// ---------------------------------------------------------------------------

abstract final class AppColors {
  /// بداية تدرج الزر الكبير.
  static const Color goldLight = Color(0xFFE6CF94);

  /// تعبئة الأشرطة والنقاط. ممنوع للنص؛ استخدم PentaraColors.goldText.
  static const Color gold500 = Color(0xFFC9A75A);

  /// بداية تدرج الأقراص الذهبية (145°).
  static const Color goldDiscStart = Color(0xFFD9B868);

  /// نهاية تدرج الأقراص الذهبية (145°).
  static const Color goldDeep = Color(0xFF8C6A1D);

  /// نص الزر الذهبي الكبير: كحلي ثابت في الوضعين.
  /// لا يُربط بـ ink لأن ink يصبح كريمياً في الداكن.
  static const Color onGold = Color(0xFF14182B);

  /// #A8832F بشفافية 0.16 (0.16 × 255 ≈ 41 = 0x29).
  static const Color goldShadowColor = Color(0x29A8832F);

  /// الظل الذهبي: لبطاقة الخلاصة والباقة العليا فقط.
  static const List<BoxShadow> goldShadow = [
    BoxShadow(
      color: goldShadowColor,
      offset: Offset(0, 10),
      blurRadius: 30,
    ),
  ];

  /// اتجاه 145° (بصيغة CSS) محوَّلاً إلى Alignment:
  /// المتجه (sin 145°, −cos 145°) ≈ (0.574, 0.819)، وطوله 1،
  /// فيقع الطرفان على محيط القرص. Alignment لا يتأثر باتجاه RTL.
  static const Alignment disc145Begin = Alignment(-0.574, -0.819);
  static const Alignment disc145End = Alignment(0.574, 0.819);

  /// تدرج قرص بزاوية 145° من لونين.
  static LinearGradient discGradient(Color start, Color end) {
    return LinearGradient(
      begin: disc145Begin,
      end: disc145End,
      colors: [start, end],
    );
  }

  /// تدرج الأقراص الذهبية.
  static const LinearGradient goldDiscGradient = LinearGradient(
    begin: disc145Begin,
    end: disc145End,
    colors: [goldDiscStart, goldDeep],
  );
}

// ---------------------------------------------------------------------------
// ألوان الحالات (حبر + خلفية)
// ---------------------------------------------------------------------------

/// ok: سليم، متحقق، موثَّق.
/// warn: قيد النقاش، مُختبَر.
/// info: قيد الاختبار، مُراجَع.
/// danger: مرفوض، يحتاج تصحيحاً.
/// neutral: فكرة، مُولَّد.
/// (ربط الحالات بالدلالات يتم في models.dart لاحقاً.)
enum StatusTone { ok, warn, info, danger, neutral }

@immutable
class ToneColors {
  const ToneColors({required this.ink, required this.bg});

  final Color ink;
  final Color bg;

  static ToneColors lerp(ToneColors a, ToneColors b, double t) {
    return ToneColors(
      ink: Color.lerp(a.ink, b.ink, t)!,
      bg: Color.lerp(a.bg, b.bg, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ToneColors && other.ink == ink && other.bg == bg;

  @override
  int get hashCode => Object.hash(ink, bg);
}

// ---------------------------------------------------------------------------
// الأعضاء
// ---------------------------------------------------------------------------

/// معرّفات الأعضاء بترتيب الجدول. يُعرَّف مرة واحدة هنا.
/// الألقاب والأدوار النصية تُعرَّف في models.dart لاحقاً.
enum MemberId { chair, engineer, practical, analyst, challenger, auditor }

/// ألوان العضو: لون الاسم يتبدّل بين الوضعين، والتدرج ثابت.
@immutable
class MemberPalette {
  const MemberPalette({
    required this.nameLight,
    required this.nameDark,
    required this.discStart,
    required this.discEnd,
  });

  final Color nameLight;
  final Color nameDark;
  final Color discStart;
  final Color discEnd;

  LinearGradient get disc => AppColors.discGradient(discStart, discEnd);
}

extension MemberPaletteX on MemberId {
  MemberPalette get palette => switch (this) {
        // رئيس الجلسة: قيمه تطابق goldText/goldDeep رقماً، وتُكتب مستقلة.
        MemberId.chair => const MemberPalette(
            nameLight: Color(0xFF8C6A1D),
            nameDark: Color(0xFFE6CF94),
            discStart: Color(0xFFD9B868),
            discEnd: Color(0xFF8C6A1D),
          ),
        MemberId.engineer => const MemberPalette(
            nameLight: Color(0xFFA6482B),
            nameDark: Color(0xFFE08A6A),
            discStart: Color(0xFFD07A5C),
            discEnd: Color(0xFFA6482B),
          ),
        // العملي: #0B7A5E. ليس teal (#0B7A6E).
        MemberId.practical => const MemberPalette(
            nameLight: Color(0xFF0B7A5E),
            nameDark: Color(0xFF4CC39F),
            discStart: Color(0xFF2FA584),
            discEnd: Color(0xFF0B7A5E),
          ),
        MemberId.analyst => const MemberPalette(
            nameLight: Color(0xFF2F62C9),
            nameDark: Color(0xFF7FA6F0),
            discStart: Color(0xFF5F8BE0),
            discEnd: Color(0xFF2F62C9),
          ),
        MemberId.challenger => const MemberPalette(
            nameLight: Color(0xFF525866),
            nameDark: Color(0xFFB4BAC7),
            discStart: Color(0xFF7D8494),
            discEnd: Color(0xFF3F4450),
          ),
        MemberId.auditor => const MemberPalette(
            nameLight: Color(0xFF3049D6),
            nameDark: Color(0xFF8C9CF5),
            discStart: Color(0xFF6178EA),
            discEnd: Color(0xFF3049D6),
          ),
      };
}

// ---------------------------------------------------------------------------
// امتداد الثيم: الألوان المتبدّلة بين الفاتح والداكن
// ---------------------------------------------------------------------------

@immutable
class PentaraColors extends ThemeExtension<PentaraColors> {
  const PentaraColors({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceSoft,
    required this.border,
    required this.track,
    required this.ink,
    required this.inkMuted,
    required this.goldLine,
    required this.goldText,
    required this.teal,
    required this.ok,
    required this.warn,
    required this.info,
    required this.danger,
    required this.neutral,
  });

  final Brightness brightness;

  /// خلفية الشاشات.
  final Color bg;

  /// البطاقات والشريط السفلي.
  final Color surface;

  /// بطاقة مختارة، ملاحظة رئيس الجلسة.
  final Color surfaceSoft;

  /// حدود 1px.
  final Color border;

  /// مسار الأشرطة.
  final Color track;

  /// النص الأساسي.
  final Color ink;

  /// النص الثانوي.
  final Color inkMuted;

  /// الحدود الذهبية.
  final Color goldLine;

  /// أي نص ذهبي.
  final Color goldText;

  /// حلقة الشعار فقط. لا تُستخدم للعملي (اسمه #0B7A5E).
  final Color teal;

  final ToneColors ok;
  final ToneColors warn;
  final ToneColors info;
  final ToneColors danger;
  final ToneColors neutral;

  static const PentaraColors light = PentaraColors(
    brightness: Brightness.light,
    bg: Color(0xFFF7F3EA),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFFBF6EA),
    border: Color(0xFFE5DDC8),
    track: Color(0xFFEFE8D6),
    ink: Color(0xFF14182B),
    inkMuted: Color(0xFF5E6680),
    goldLine: Color(0xFFA8832F),
    goldText: Color(0xFF8C6A1D),
    teal: Color(0xFF0B7A6E),
    ok: ToneColors(ink: Color(0xFF1F6B4A), bg: Color(0xFFE2F2EA)),
    warn: ToneColors(ink: Color(0xFF7A4C00), bg: Color(0xFFFBEED6)),
    info: ToneColors(ink: Color(0xFF2F4F9E), bg: Color(0xFFE6ECF8)),
    danger: ToneColors(ink: Color(0xFFA8322E), bg: Color(0xFFFBE5E4)),
    neutral: ToneColors(ink: Color(0xFF4E556B), bg: Color(0xFFECEAE3)),
  );

  static const PentaraColors dark = PentaraColors(
    brightness: Brightness.dark,
    bg: Color(0xFF0E1428),
    surface: Color(0xFF161F3A),
    surfaceSoft: Color(0xFF1C2747),
    border: Color(0xFF2A3354),
    track: Color(0xFF26304F),
    ink: Color(0xFFF2EEE3),
    inkMuted: Color(0xFFA3ABC4),
    goldLine: Color(0xFFC9A75A),
    goldText: Color(0xFFE6CF94),
    teal: Color(0xFF3FB8A8),
    ok: ToneColors(ink: Color(0xFF7FDDB3), bg: Color(0xFF173A2C)),
    warn: ToneColors(ink: Color(0xFFF2C77A), bg: Color(0xFF3A2E14)),
    info: ToneColors(ink: Color(0xFF9DB6F2), bg: Color(0xFF1C2A4F)),
    danger: ToneColors(ink: Color(0xFFF29A95), bg: Color(0xFF40201F)),
    neutral: ToneColors(ink: Color(0xFFC2C7D4), bg: Color(0xFF262D45)),
  );

  /// زوج ألوان الحالة.
  ToneColors tone(StatusTone t) => switch (t) {
        StatusTone.ok => ok,
        StatusTone.warn => warn,
        StatusTone.info => info,
        StatusTone.danger => danger,
        StatusTone.neutral => neutral,
      };

  /// لون اسم العضو محسوماً للوضع الحالي، بلا تفريع isDark في الشاشات.
  Color memberName(MemberId id) => brightness == Brightness.dark
      ? id.palette.nameDark
      : id.palette.nameLight;

  /// تدرج قرص العضو (ثابت في الوضعين).
  LinearGradient memberDisc(MemberId id) => id.palette.disc;

  @override
  PentaraColors copyWith({
    Brightness? brightness,
    Color? bg,
    Color? surface,
    Color? surfaceSoft,
    Color? border,
    Color? track,
    Color? ink,
    Color? inkMuted,
    Color? goldLine,
    Color? goldText,
    Color? teal,
    ToneColors? ok,
    ToneColors? warn,
    ToneColors? info,
    ToneColors? danger,
    ToneColors? neutral,
  }) {
    return PentaraColors(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      border: border ?? this.border,
      track: track ?? this.track,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      goldLine: goldLine ?? this.goldLine,
      goldText: goldText ?? this.goldText,
      teal: teal ?? this.teal,
      ok: ok ?? this.ok,
      warn: warn ?? this.warn,
      info: info ?? this.info,
      danger: danger ?? this.danger,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  PentaraColors lerp(ThemeExtension<PentaraColors>? other, double t) {
    if (other is! PentaraColors) return this;
    return PentaraColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      border: Color.lerp(border, other.border, t)!,
      track: Color.lerp(track, other.track, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      goldLine: Color.lerp(goldLine, other.goldLine, t)!,
      goldText: Color.lerp(goldText, other.goldText, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      ok: ToneColors.lerp(ok, other.ok, t),
      warn: ToneColors.lerp(warn, other.warn, t),
      info: ToneColors.lerp(info, other.info, t),
      danger: ToneColors.lerp(danger, other.danger, t),
      neutral: ToneColors.lerp(neutral, other.neutral, t),
    );
  }
}

/// وصول مختصر: context.colors.ink
extension PentaraColorsContext on BuildContext {
  PentaraColors get colors =>
      Theme.of(this).extension<PentaraColors>() ?? PentaraColors.light;
}
