import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// يلفّ بطاقة ليمكن مشاركتها صورةً مع نص (رابط الإحالة).
/// [builder] يستلم زر المشاركة ليضعه داخل البطاقة؛ الزر يختفي أثناء التصوير.
class ShareableCard extends StatefulWidget {
  const ShareableCard({
    super.key,
    required this.shareText,
    required this.fileName,
    required this.builder,
  });

  final String shareText;
  final String fileName;
  final Widget Function(BuildContext context, Widget shareButton) builder;

  @override
  State<ShareableCard> createState() => _ShareableCardState();
}

class _ShareableCardState extends State<ShareableCard> {
  final GlobalKey _boundary = GlobalKey();
  bool _capturing = false;
  bool _busy = false;

  Future<Uint8List?> _capture() async {
    setState(() => _capturing = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      final obj = _boundary.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) return null;
      final image = await obj.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    _busy = true;
    try {
      final bytes = await _capture();
      if (bytes != null) {
        try {
          await Share.shareXFiles(
            [XFile.fromData(bytes, mimeType: 'image/png', name: widget.fileName)],
            text: widget.shareText,
          );
          return;
        } catch (_) {
          // بعض المتصفحات لا تقبل مشاركة الصور: نشارك النص وحده.
        }
      }
      try {
        await Share.share(widget.shareText);
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: widget.shareText));
        if (mounted) {
          final c = context.colors;
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: c.ink,
            content: Text('نُسخ رابط الإحالة', style: AppTypography.label.copyWith(color: c.bg)),
          ));
        }
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = Opacity(
      opacity: _capturing ? 0 : 1,
      child: Semantics(
        button: true,
        label: 'مشاركة البطاقة ورابط الإحالة',
        child: Material(
          color: const Color(0x1FE6CF94),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _capturing ? null : _share,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(Icons.ios_share_rounded, size: 20, color: Color(0xFFE6CF94)),
              ),
            ),
          ),
        ),
      ),
    );
    return RepaintBoundary(
      key: _boundary,
      child: widget.builder(context, button),
    );
  }
}
