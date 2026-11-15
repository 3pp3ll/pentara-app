import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'member_icons.dart';
import 'status_chip.dart';

/// رسالة في النقاش.
///
/// - حافة 3px بلون العضو على جهة البداية (يميناً في RTL)، تُرسم بـ
///   PositionedDirectional داخل ClipRRect، فلا تتعارض مع الزاوية 16.
/// - ملاحظة الرئيس (بلا حكم) على surfaceSoft وبلا شارة «سليم» مصطنعة.
/// - الشارة (سليم أو مرفوض) مع سطر السبب مستقل تحت النص.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.sender,
  });

  final Message message;
  final Member sender;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nameColor = c.memberName(sender.id);
    final verdict = message.verdict;
    final reason = message.reason;
    final isNote = message.isChairNote && verdict == null;
    final hasReason = reason != null && reason.isNotEmpty;

    final reasonColor =
        verdict == MessageVerdict.rejected ? c.danger.ink : c.inkMuted;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isNote ? c.surfaceSoft : c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(15, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MemberIcon(
                            symbol: sender.symbol,
                            size: 16,
                            color: nameColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sender.title,
                            style:
                                AppTypography.label.copyWith(color: nameColor),
                          ),
                        ],
                      ),
                      Text(
                        toArabicDigits('الجولة ${message.roundNumber}'),
                        style:
                            AppTypography.caption.copyWith(color: c.inkMuted),
                      ),
                      if (verdict != null) StatusChip.verdict(verdict),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.text,
                    style: AppTypography.body.copyWith(color: c.ink),
                  ),
                  if (hasReason) ...[
                    const SizedBox(height: 8),
                    Text(
                      'السبب: $reason',
                      style: AppTypography.caption.copyWith(color: reasonColor),
                    ),
                  ],
                ],
              ),
            ),
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: ColoredBox(color: nameColor),
            ),
          ],
        ),
      ),
    );
  }
}
