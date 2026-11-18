import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// ألوان الهوية للأيقونات: نفس تدرجات أعضاء الجلسة.
enum GlyphTone { gold, copper, emerald, blue, slate, indigo }

extension GlyphToneX on GlyphTone {
  LinearGradient get gradient => switch (this) {
        GlyphTone.gold => MemberId.chair.palette.disc,
        GlyphTone.copper => MemberId.engineer.palette.disc,
        GlyphTone.emerald => MemberId.practical.palette.disc,
        GlyphTone.blue => MemberId.analyst.palette.disc,
        GlyphTone.slate => MemberId.challenger.palette.disc,
        GlyphTone.indigo => MemberId.auditor.palette.disc,
      };

  Color get shadow => gradient.colors.last;

  /// تناوب الألوان حسب ترتيب العنصر.
  static GlyphTone at(int i) => const [
        GlyphTone.gold,
        GlyphTone.emerald,
        GlyphTone.blue,
        GlyphTone.copper,
        GlyphTone.indigo,
        GlyphTone.slate,
      ][i % 6];
}

/// أيقونة التطبيق الموحّدة: مربع بزوايا ناعمة بتدرج من ألوان الهوية ورمز أبيض.
class Glyph extends StatelessWidget {
  const Glyph(this.icon, {super.key, this.tone = GlyphTone.gold, this.size = 44, this.dim = false});

  final IconData icon;
  final GlyphTone tone;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.33),
          gradient: tone.gradient,
          boxShadow: [
            BoxShadow(color: tone.shadow.withAlpha(55), blurRadius: size * 0.22, offset: Offset(0, size * 0.08)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.52),
      ),
    );
  }
}

/// ألوان أنواع المخرجات ثابتة في كل الشاشات.
GlyphTone outputTone(int index) => GlyphToneX.at(index);
