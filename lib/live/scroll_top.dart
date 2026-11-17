import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// زر «للأعلى» يظهر عندما تطول الصفحة، ويعود بها لأولها بحركة ناعمة.
/// يوضع داخل Stack فوق القائمة.
class ScrollTopButton extends StatefulWidget {
  const ScrollTopButton({super.key, required this.controller, this.threshold = 500});

  final ScrollController controller;
  final double threshold;

  @override
  State<ScrollTopButton> createState() => _ScrollTopButtonState();
}

class _ScrollTopButtonState extends State<ScrollTopButton> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_check);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!widget.controller.hasClients) return;
    final v = widget.controller.offset > widget.threshold;
    if (v != _show) setState(() => _show = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PositionedDirectional(
      end: 16,
      bottom: 16,
      child: IgnorePointer(
        ignoring: !_show,
        child: AnimatedOpacity(
          opacity: _show ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Semantics(
            button: true,
            label: 'العودة لأعلى الصفحة',
            child: Material(
              shape: const CircleBorder(),
              elevation: 3,
              color: c.surface,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => widget.controller.animateTo(
                  0,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                ),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.goldLine),
                  ),
                  child: Icon(Icons.keyboard_arrow_up_rounded, color: c.goldText, size: 28),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// حفظ نص الخلاصة كملف .txt عبر قائمة المشاركة (حفظ في الملفات/التنزيلات أو إرسال)،
/// وإن تعذّر يُنسخ النص.
Future<void> exportText(BuildContext context, String title, String text) async {
  final safe = title.replaceAll(RegExp(r'[\\/:*?"<>|\n]'), ' ').trim();
  final name = 'بنتارا - ${safe.isEmpty ? 'خلاصة' : safe}.txt';
  final messenger = ScaffoldMessenger.maybeOf(context);
  final c = context.colors;
  try {
    await Share.shareXFiles(
      [XFile.fromData(utf8.encode(text), mimeType: 'text/plain', name: name)],
      subject: name,
    );
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    messenger?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.ink,
      content: Text('تعذّر حفظ الملف هنا، فنُسخت الخلاصة', style: AppTypography.label.copyWith(color: c.bg)),
    ));
  }
}
