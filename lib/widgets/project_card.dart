import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'status_chip.dart';

/// أرقام غربية متساوية العرض بخط Alexandria (للأسعار والمؤشرات).
/// تُعرض دائماً داخل Directionality(textDirection: TextDirection.ltr).
TextStyle latinFigures(TextStyle base) {
  return base.copyWith(
    fontFamily: AppFonts.latin,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// بطاقة مشروع: سطح وحد بلا ظل. لا تقرأ AppState.
///
/// - [showDetails] = false (الرئيسية): قرص وبطاقة الحالة فقط.
/// - [showDetails] = true (المشاريع): الوصف في سطر واحد، وسطر الجاهزية،
///   والتكلفة.
/// الحالة والجاهزية تُقرآن مستقلتين من المشروع، ولا تُشتق إحداهما من الأخرى.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
    this.showDetails = true,
  });

  final Project project;
  final VoidCallback? onTap;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = project;
    final radius = BorderRadius.circular(20);
    final overlay = c.goldLine.withAlpha(31); // 0.12

    final semanticsLabel = showDetails
        ? '${p.name}، ${p.status.label}، الجاهزية: ${p.readiness.label}'
        : '${p.name}، ${p.status.label}';

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: radius,
            border: Border.all(color: c.border, width: 1),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            highlightColor: overlay,
            hoverColor: overlay,
            focusColor: overlay,
            splashColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MarkDisc(mark: p.mark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                AppTypography.bodyStrong.copyWith(color: c.ink),
                          ),
                          if (showDetails) ...[
                            const SizedBox(height: 2),
                            Text(
                              p.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label
                                  .copyWith(color: c.inkMuted),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    StatusChip.projectStatus(p.status),
                                    if (showDetails)
                                      Text(
                                        'الجاهزية: ${p.readiness.label}',
                                        style: AppTypography.caption
                                            .copyWith(color: c.inkMuted),
                                      ),
                                  ],
                                ),
                              ),
                              if (showDetails) ...[
                                const SizedBox(width: 8),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    p.costLabel,
                                    style: latinFigures(AppTypography.label)
                                        .copyWith(color: c.ink),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// قرص العلامة: تدرّج goldLight→gold500 وحرف onGold (لا أبيض على فاتح).
class _MarkDisc extends StatelessWidget {
  const _MarkDisc({required this.mark});

  final String mark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.discGradient(AppColors.goldLight, AppColors.gold500),
      ),
      child: ExcludeSemantics(
        child: Text(
          mark,
          style: AppTypography.title.copyWith(color: AppColors.onGold),
        ),
      ),
    );
  }
}
