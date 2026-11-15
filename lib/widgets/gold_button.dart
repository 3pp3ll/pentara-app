import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum _GoldButtonVariant { primary, secondary, disc }

/// أزرار بنتارا الذهبية: أساسي، ثانوي، وقرص.
///
/// - لا ظل ذهبي على أي زر (الظل لبطاقة الخلاصة والباقة العليا فقط).
/// - الأساسي: تدرّج goldLight→gold500 ونص onGold الثابت في الوضعين.
/// - onTap == null يعني تعطيلاً حقيقياً: عتامة 0.40 بلا طبقة ضغط.
/// - الضغط: Material ← Ink ← InkWell، وطبقة اللون مشتقة بـ withAlpha
///   (لا withOpacity ولا withValues).
/// - [GoldButton.disc] هدف لمس 44×44، وlabel وicon مطلوبان فيه،
///   مع Tooltip وSemantics.
class GoldButton extends StatelessWidget {
  const GoldButton._({
    super.key,
    required _GoldButtonVariant variant,
    required this.label,
    this.icon,
    this.onTap,
    this.filled = false,
    this.expand = false,
  }) : _variant = variant;

  const GoldButton.primary({
    Key? key,
    required String label,
    VoidCallback? onTap,
    Widget? icon,
    bool expand = false,
  }) : this._(
          key: key,
          variant: _GoldButtonVariant.primary,
          label: label,
          onTap: onTap,
          icon: icon,
          expand: expand,
        );

  const GoldButton.secondary({
    Key? key,
    required String label,
    VoidCallback? onTap,
    Widget? icon,
    bool expand = false,
  }) : this._(
          key: key,
          variant: _GoldButtonVariant.secondary,
          label: label,
          onTap: onTap,
          icon: icon,
          expand: expand,
        );

  const GoldButton.disc({
    Key? key,
    required String label,
    required Widget icon,
    VoidCallback? onTap,
    bool filled = false,
  }) : this._(
          key: key,
          variant: _GoldButtonVariant.disc,
          label: label,
          icon: icon,
          onTap: onTap,
          filled: filled,
        );

  final _GoldButtonVariant _variant;
  final String label;
  final Widget? icon;
  final VoidCallback? onTap;

  /// للقرص فقط: تعبئة ذهبية (إشعارات) أو سطح محدّد (إعادة وترتيب).
  final bool filled;

  /// للأساسي والثانوي: يملأ العرض المتاح.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onTap != null;

    final goldFill = BoxDecoration(
      gradient: AppColors.discGradient(AppColors.goldLight, AppColors.gold500),
    );
    final onGoldOverlay = AppColors.onGold.withAlpha(36); // 0.14
    final surfaceOverlay = c.goldLine.withAlpha(31); // 0.12

    Widget body;
    switch (_variant) {
      case _GoldButtonVariant.primary:
        body = _inkSurface(
          decoration: goldFill.copyWith(
            borderRadius: BorderRadius.circular(999),
          ),
          shape: const StadiumBorder(),
          overlay: onGoldOverlay,
          child: _content(
            minHeight: 56,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            style: AppTypography.bodyStrong.copyWith(color: AppColors.onGold),
          ),
        );
      case _GoldButtonVariant.secondary:
        body = _inkSurface(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: c.goldLine, width: 1),
          ),
          shape: const StadiumBorder(),
          overlay: surfaceOverlay,
          child: _content(
            minHeight: 44,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            style: AppTypography.label.copyWith(color: c.ink),
          ),
        );
      case _GoldButtonVariant.disc:
        body = SizedBox(
          width: 44,
          height: 44,
          child: _inkSurface(
            decoration: filled
                ? goldFill.copyWith(shape: BoxShape.circle)
                : BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.surface,
                    border: Border.all(color: c.goldLine, width: 1),
                  ),
            shape: const CircleBorder(),
            overlay: filled ? onGoldOverlay : surfaceOverlay,
            child: Center(child: icon),
          ),
        );
    }

    Widget result = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(opacity: enabled ? 1.0 : 0.40, child: body),
    );

    if (_variant == _GoldButtonVariant.disc) {
      result = Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: result,
      );
    }
    return result;
  }

  Widget _inkSurface({
    required BoxDecoration decoration,
    required ShapeBorder shape,
    required Color overlay,
    required Widget child,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          highlightColor: overlay,
          hoverColor: overlay,
          focusColor: overlay,
          splashColor: Colors.transparent,
          child: child,
        ),
      ),
    );
  }

  Widget _content({
    required double minHeight,
    required EdgeInsets padding,
    required TextStyle style,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight, minWidth: 44),
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
