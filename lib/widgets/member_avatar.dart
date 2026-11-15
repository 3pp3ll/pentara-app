import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import 'member_icons.dart';

/// قرص العضو: دائرة متدرّجة (145°) برمز أبيض.
///
/// [size] هو الصندوق الخارجي الثابت: لا يُرسم شيء خارجه، فلا يقفز صف
/// الأعضاء عند تبدّل المتحدث. المتحدث أكبر بهالة بلون العضو ونبض دورته
/// 1.6 ث (800ms مع reverse). الباقون بشفافية 0.85 على القرص كله.
///
/// يتوقف النبض تلقائياً مع TickerMode (تبويب مخفي)، ومع تقليل الحركة
/// تبقى الهالة ثابتة. وصف Semantics فقط، بلا Tooltip (عرض لا تفاعل).
class MemberAvatar extends StatefulWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    required this.size,
    this.isSpeaking = false,
  });

  final Member member;
  final double size;
  final bool isSpeaking;

  @override
  State<MemberAvatar> createState() => _MemberAvatarState();
}

class _MemberAvatarState extends State<MemberAvatar>
    with SingleTickerProviderStateMixin {
  static const Color _white = Color(0xFFFFFFFF);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant MemberAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.isSpeaking && !_reduceMotion) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = widget.isSpeaking ? 0.5 : 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = widget.member;
    final size = widget.size;
    final speaking = widget.isSpeaking;
    final base = size * 0.66;
    final haloColor = c.memberName(m.id);

    final label = speaking
        ? '${m.title}، ${m.role}، يتحدث الآن'
        : '${m.title}، ${m.role}';

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (speaking)
              AnimatedBuilder(
                key: const ValueKey('halo'),
                animation: _pulse,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(_pulse.value);
                  final d = size * (0.84 + 0.16 * t);
                  final alpha = ((0.14 + 0.20 * t) * 255).round();
                  return Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: haloColor.withAlpha(alpha),
                    ),
                  );
                },
              ),
            AnimatedScale(
              key: const ValueKey('disc'),
              scale: speaking ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: speaking ? 1.0 : 0.85,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: base,
                  height: base,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: m.palette.disc,
                  ),
                  child: MemberIcon(
                    symbol: m.symbol,
                    size: base * 0.52,
                    color: _white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
