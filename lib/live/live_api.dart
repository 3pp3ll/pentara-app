import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// رابط سيرفر بنتارا (Cloudflare Worker). يُغيَّر هنا فقط.
const String kServerUrl = 'https://pentara-api.3pp3ll.workers.dev';

class LiveException implements Exception {
  LiveException(this.message, [this.status = 0]);
  final String message;
  final int status;
  @override
  String toString() => message;
}

/// حساب حقيقي من السيرفر. المبالغ بالمايكرو دولار.
class LiveUser {
  const LiveUser({
    required this.id,
    required this.plan,
    required this.planName,
    required this.balanceMicros,
    required this.spentMicros,
    required this.disabled,
    required this.isOwner,
  });

  factory LiveUser.fromJson(Map<String, dynamic> j) => LiveUser(
        id: '${j['id'] ?? ''}',
        plan: '${j['plan'] ?? 'none'}',
        planName: '${j['planName'] ?? ''}',
        balanceMicros: (j['balanceMicros'] as num?)?.toInt() ?? 0,
        spentMicros: (j['spentMicros'] as num?)?.toInt() ?? 0,
        disabled: j['disabled'] == true,
        isOwner: j['isOwner'] == true,
      );

  final String id;
  final String plan;
  final String planName;
  final int balanceMicros;
  final int spentMicros;
  final bool disabled;
  final bool isOwner;

  bool get hasPlan => plan != 'none';
  String get balanceLabel => formatMicros(balanceMicros);
}

String formatMicros(int micros) => '\$${(micros / 1000000).toStringAsFixed(2)}';

/// رد مقعد واحد من الطاولة.
class SeatReply {
  const SeatReply({
    required this.text,
    required this.costMicros,
    required this.balanceMicros,
    required this.cut,
  });
  final String text;
  final int costMicros;
  final int balanceMicros;
  final bool cut;
}

/// حالة الحساب الحقيقي: الدخول والرصيد والتفعيل. نسخة واحدة للتطبيق.
class LiveController extends ChangeNotifier {
  LiveController._();
  static final LiveController instance = LiveController._();

  static const String _prefsKey = 'pentara-login';

  /// نص الإحالة تحت بطاقة المستخدم: يُعدَّل ويُخفى من لوحة التحكم على الويب.
  static const String defaultReferText =
      'ادعُ صديقاً: تحصل على \$5 من اشتراكه و500 نقطة، ويحصل هو على 100 نقطة. '
      'إن اشترك في الباقة العليا تحصل على \$10 و1500 نقطة.';
  String referText = defaultReferText;
  bool referVisible = true;

  String? _login;
  LiveUser? _user;
  bool _busy = false;
  bool _ready = false;
  String? _error;

  LiveUser? get user => _user;
  bool get isSignedIn => _login != null && _user != null;
  bool get busy => _busy;
  bool get ready => _ready;
  String? get error => _error;
  bool get configured => !kServerUrl.contains('SUBDOMAIN');

  Uri _u(String path) => Uri.parse('$kServerUrl$path');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_login != null) 'Authorization': 'Bearer $_login',
      };

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 40),
  }) async {
    if (!configured) {
      throw LiveException('السيرفر لم يُربط بعد');
    }
    http.Response res;
    try {
      final f = method == 'GET'
          ? http.get(_u(path), headers: _headers)
          : http.post(_u(path), headers: _headers, body: jsonEncode(body ?? {}));
      res = await f.timeout(timeout);
    } on TimeoutException {
      throw LiveException('تأخر الرد. تحقق من الاتصال وحاول مرة أخرى');
    } catch (_) {
      throw LiveException('تعذّر الاتصال بالسيرفر. تحقق من الإنترنت');
    }
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw LiveException('${data['error'] ?? 'خطأ ${res.statusCode}'}', res.statusCode);
    }
    return data;
  }

  void _setUser(Map<String, dynamic> data) {
    final u = data['user'];
    if (u is Map<String, dynamic>) _user = LiveUser.fromJson(u);
  }

  Future<void> _run(Future<void> Function() job) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await job();
    } on LiveException catch (e) {
      _error = e.message;
      if (e.status == 401 || e.status == 403) await _forget(keepError: true);
    } catch (_) {
      _error = 'حدث خطأ غير متوقع';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// يُستدعى مرة عند تشغيل التطبيق.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _login = prefs.getString(_prefsKey);
    } catch (_) {}
    if (configured) {
      try {
        final data = await _send('GET', '/api/config', timeout: const Duration(seconds: 12));
        final cfg = data['config'];
        if (cfg is Map<String, dynamic>) {
          final t = '${cfg['referText'] ?? ''}'.trim();
          if (t.isNotEmpty) referText = t;
          referVisible = cfg['referVisible'] != false;
        }
      } catch (_) {}
    }
    if (_login != null && configured) {
      await _run(() async => _setUser(await _send('GET', '/api/me')));
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_login == null) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, _login!);
      }
    } catch (_) {}
  }

  Future<void> _forget({bool keepError = false}) async {
    _login = null;
    _user = null;
    if (!keepError) _error = null;
    await _save();
  }

  Future<void> register() => _run(() async {
        final data = await _send('POST', '/api/register');
        _login = '${data['login']}';
        _setUser(data);
        await _save();
      });

  /// رمز دخول يصدره المشرف: «12345678.xxxx».
  Future<void> useLogin(String raw) => _run(() async {
        final v = raw.trim();
        if (!RegExp(r'^\d{8}\.[a-f0-9]{48}$').hasMatch(v)) {
          throw LiveException('رمز الدخول غير صحيح');
        }
        _login = v;
        try {
          _setUser(await _send('GET', '/api/me'));
          await _save();
        } catch (e) {
          _login = null;
          rethrow;
        }
      });

  Future<void> activate(String code) => _run(() async {
        if (code.trim().isEmpty) throw LiveException('الصق كود الاشتراك');
        _setUser(await _send('POST', '/api/activate', body: {'code': code.trim()}));
      });

  Future<void> refresh() => _run(() async => _setUser(await _send('GET', '/api/me')));

  Future<void> signOut() async {
    await _forget();
    notifyListeners();
  }

  /// مقعد واحد يتكلم. السيرفر يختار النموذج حسب الباقة ويخصم التكلفة.
  Future<SeatReply> speak({
    required String seat,
    required String kind,
    required List<Map<String, String>> messages,
    bool code = false,
  }) async {
    final data = await _send(
      'POST',
      '/api/chat',
      body: {'seat': seat, 'kind': kind, 'messages': messages, 'code': code},
      timeout: const Duration(minutes: 4),
    );
    final reply = SeatReply(
      text: '${data['text'] ?? ''}'.trim(),
      costMicros: (data['costMicros'] as num?)?.toInt() ?? 0,
      balanceMicros: (data['balanceMicros'] as num?)?.toInt() ?? 0,
      cut: data['finish'] == 'length',
    );
    final u = _user;
    if (u != null) {
      _user = LiveUser(
        id: u.id,
        plan: u.plan,
        planName: u.planName,
        balanceMicros: reply.balanceMicros,
        spentMicros: u.spentMicros + reply.costMicros,
        disabled: u.disabled,
        isOwner: u.isOwner,
      );
      notifyListeners();
    }
    return reply;
  }
}
