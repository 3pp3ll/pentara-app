import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'reload_stub.dart' if (dart.library.js_interop) 'reload_web.dart';

/// رقم البناء يُمرَّر من GitHub Actions (--dart-define=BUILD=رقم التشغيل).
const int kBuild = int.fromEnvironment('BUILD', defaultValue: 0);
const String kSiteUrl = 'https://3pp3ll.github.io/pentara-app/';

/// يتحقق من وجود نسخة أحدث (version.json بجانب نسخة الويب) ويحدّث:
/// الموقع يعيد التحميل تلقائياً، والأندرويد ينزّل النسخة الجديدة.
class AppUpdate extends ChangeNotifier {
  AppUpdate._();
  static final AppUpdate instance = AppUpdate._();

  int latest = 0;
  String apkUrl = '${kSiteUrl}app.apk';
  bool available = false;
  bool updating = false;

  Future<void> check() async {
    if (kBuild == 0) return; // نسخة محلية بلا رقم بناء
    try {
      final res = await http
          .get(Uri.parse('${kSiteUrl}version.json?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return;
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is! Map) return;
      latest = (j['build'] as num?)?.toInt() ?? 0;
      final apk = '${j['apk'] ?? ''}';
      if (apk.startsWith('https://')) apkUrl = apk;
      if (latest <= kBuild) return;
      available = true;
      notifyListeners();
      if (kIsWeb) await _webAuto();
    } catch (_) {}
  }

  /// الموقع: يعيد التحميل مرة واحدة لكل نسخة (حتى لا يدور في حلقة إن بقي مخزّناً).
  Future<void> _webAuto() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt('pentara-update-tried') == latest) return;
      await prefs.setInt('pentara-update-tried', latest);
    } catch (_) {}
    updating = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    reloadPage();
  }

  Future<void> apply() async {
    updating = true;
    notifyListeners();
    if (kIsWeb) {
      reloadPage();
      return;
    }
    final ok = await launchUrl(Uri.parse(apkUrl), mode: LaunchMode.externalApplication);
    if (!ok) {
      updating = false;
      notifyListeners();
    }
  }
}

/// شريط أعلى التطبيق: «جاري تحديث نسخة التطبيق».
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final up = AppUpdate.instance;
    return ListenableBuilder(
      listenable: up,
      builder: (context, _) {
        if (!up.available) return const SizedBox.shrink();
        final c = context.colors;
        const ink = Color(0xFF14182B);
        final text = up.updating
            ? (kIsWeb
                ? 'جاري تحديث نسخة التطبيق…'
                : 'جاري تنزيل التحديث… افتحه من الإشعارات واضغط «تثبيت»')
            : 'نسخة جديدة من بنتارا متوفرة';
        return Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(colors: [Color(0xFFE6CF94), Color(0xFFC9A75A)]),
              boxShadow: const [BoxShadow(color: Color(0x29A8832F), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: Row(
              children: [
                if (up.updating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: ink),
                  )
                else
                  const Icon(Icons.system_update_rounded, color: ink, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(text, style: AppTypography.label.copyWith(color: ink, fontWeight: FontWeight.w600)),
                ),
                if (!up.updating)
                  TextButton(
                    onPressed: up.apply,
                    style: TextButton.styleFrom(
                      backgroundColor: ink,
                      foregroundColor: c.bg,
                      minimumSize: const Size(44, 40),
                      shape: const StadiumBorder(),
                    ),
                    child: Text('تحديث الآن',
                        style: AppTypography.label.copyWith(color: const Color(0xFFE6CF94))),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
