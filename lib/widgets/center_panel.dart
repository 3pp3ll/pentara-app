import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// نافذة منبثقة في منتصف الشاشة (بدل اللوحة السفلية)، بمسافة عن حواف الشاشة
/// في الجوال، وعرض محدود في الكمبيوتر، وتمرير إن طال المحتوى.
Future<T?> showCenterPanel<T>(BuildContext context, WidgetBuilder builder, {double maxWidth = 560}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      return Dialog(
        backgroundColor: ctx.colors.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: size.height * 0.86),
          child: builder(ctx),
        ),
      );
    },
  );
}
