import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// نغمات التنبيه: «اكتمل» عند جاهزية الخلاصة، و«انتبه» عند الحاجة لـ«استمرار».
/// نغمة الجوال تختلف عن نغمة الكمبيوتر.
abstract final class Chime {
  static final AudioPlayer _player = AudioPlayer();

  static bool get _desktop => const {
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      }.contains(defaultTargetPlatform);

  static Future<void> done() => _play(_desktop ? 'sounds/done_desktop.wav' : 'sounds/done_mobile.wav');

  static Future<void> attention() =>
      _play(_desktop ? 'sounds/attention_desktop.wav' : 'sounds/attention_mobile.wav');

  static Future<void> _play(String asset) async {
    try {
      await _player.stop();
      await _player.play(AssetSource(asset), volume: 0.9);
    } catch (_) {
      // الصوت تحسين فقط: أي خطأ (متصفح يمنع التشغيل مثلاً) لا يوقف الجلسة.
    }
  }
}
