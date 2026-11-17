import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// سهمان عائمان: «للأعلى» يظهر بعد النزول، و«للأسفل» يظهر إذا بقي محتوى تحت
/// (مثل نقاش طويل ما زال يُكتب). يوضع داخل Stack فوق القائمة.
class ScrollTopButton extends StatefulWidget {
  const ScrollTopButton({super.key, required this.controller, this.threshold = 500});

  final ScrollController controller;
  final double threshold;

  @override
  State<ScrollTopButton> createState() => _ScrollTopButtonState();
}

class _ScrollTopButtonState extends State<ScrollTopButton> {
  bool _up = false;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  // المحتوى يطول أثناء النقاش دون تمرير: نعيد الفحص بعد كل إعادة بناء.
  @override
  void didUpdateWidget(covariant ScrollTopButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted || !widget.controller.hasClients) return;
    final pos = widget.controller.position;
    final up = pos.pixels > widget.threshold;
    final down = pos.maxScrollExtent - pos.pixels > widget.threshold;
    if (up != _up || down != _down) setState(() {
      _up = up;
      _down = down;
    });
  }

  void _go(bool top) {
    final pos = widget.controller.position;
    widget.controller.animateTo(
      top ? 0 : pos.maxScrollExtent,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      end: 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(context, _up, Icons.keyboard_arrow_up_rounded, 'العودة لأعلى الصفحة', () => _go(true)),
          const SizedBox(height: 10),
          _btn(context, _down, Icons.keyboard_arrow_down_rounded, 'النزول لآخر الصفحة', () => _go(false)),
        ],
      ),
    );
  }

  Widget _btn(BuildContext context, bool show, IconData icon, String label, VoidCallback tap) {
    final c = context.colors;
    return IgnorePointer(
      ignoring: !show,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            shape: const CircleBorder(),
            elevation: 3,
            color: c.surface,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: tap,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.goldLine),
                ),
                child: Icon(icon, color: c.goldText, size: 28),
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
