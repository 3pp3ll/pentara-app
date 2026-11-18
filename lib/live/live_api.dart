import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
    this.name = '',
    this.email = '',
    this.guest = false,
    this.role = 'user',
    required this.plan,
    required this.planName,
    required this.balanceMicros,
    required this.spentMicros,
    required this.disabled,
    required this.isOwner,
  });

  factory LiveUser.fromJson(Map<String, dynamic> j) => LiveUser(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        email: '${j['email'] ?? ''}',
        guest: j['guest'] == true,
        role: '${j['role'] ?? 'user'}',
        plan: '${j['plan'] ?? 'none'}',
        planName: '${j['planName'] ?? ''}',
        balanceMicros: (j['balanceMicros'] as num?)?.toInt() ?? 0,
        spentMicros: (j['spentMicros'] as num?)?.toInt() ?? 0,
        disabled: j['disabled'] == true,
        isOwner: j['isOwner'] == true,
      );

  final String id;
  final String name;
  final String email;
  final bool guest;
  final String role;
  final String plan;

  /// المالك أو من منحه المالك صلاحية مشرف.
  bool get isAdmin => isOwner || role == 'admin';
  final String planName;
  final int balanceMicros;
  final int spentMicros;
  final bool disabled;
  final bool isOwner;

  bool get hasPlan => plan != 'none';

  LiveUser withBalance(int balance, int spent) => LiveUser(
        id: id,
        name: name,
        email: email,
        guest: guest,
        role: role,
        plan: plan,
        planName: planName,
        balanceMicros: balance,
        spentMicros: spent,
        disabled: disabled,
        isOwner: isOwner,
      );
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

  /// نص الإحالة تحت بطاقة المستخدم: يكتبه المالك ويُظهره من لوحة التحكم على الويب.
  String referText = '';
  bool referVisible = false;

  /// اسم الزائر قبل التسجيل: يُختار عشوائياً مرة ويُحفظ في الجهاز.
  static const List<String> guestNames = [
    'المبرمج المثالي', 'المطوّر الذكي', 'صانع الأفكار', 'رائد الأعمال', 'المبدع الطموح',
    'صاحب الرؤية', 'المخطط البارع', 'المحلل الذكي', 'المبتكر', 'صانع الفرق',
    'المستثمر الواعي', 'قائد المشروع', 'المصمم الملهم', 'الباحث الشغوف', 'صانع النجاح',
    'المهندس المبدع', 'المسوّق الذكي', 'المؤسس الطموح', 'العقل المدبّر', 'صانع المستقبل',
    'المنفّذ المحترف', 'المخترع', 'المفكر الاستراتيجي', 'صاحب المبادرة', 'المطوّر المحترف',
    'بطل الأفكار', 'الرائد الملهم', 'صانع التطبيقات', 'المحلل الاستراتيجي', 'المبدع الذكي',
  ];
  static const String _guestNameKey = 'pentara-guest-name';
  static const String _deviceKey = 'pentara-device';

  /// معرّف هذا الجهاز: الحساب العادي يعمل على أول جهاز سجّل منه فقط.
  String _device = '';
  String guestName = guestNames[Random().nextInt(guestNames.length)];

  /// إحصاءات عامة لكل المستخدمين (المختبر وملخص المشاريع قبل الدخول).
  Map<String, dynamic> globalStats = const {};

  /// مستخدم مسجّل ببريد (ليس زائراً).
  bool get isRegistered => _user != null && !_user!.guest;
  bool get isGuest => _user != null && _user!.guest;
  String get displayName =>
      isRegistered && _user!.name.trim().isNotEmpty ? _user!.name.trim() : guestName;

  String? _login;

  /// رابط لوحة التحكم على الموقع مع دخول تلقائي بحساب التطبيق (الرمز في # فلا يصل لأي سجل خادم).
  String get webAdminUrl => '$kServerUrl/admin${_login == null ? '' : '#app=${Uri.encodeComponent(_login!)}'}';
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
      final f = switch (method) {
        'GET' => http.get(_u(path), headers: _headers),
        'DELETE' => http.delete(_u(path), headers: _headers),
        _ => http.post(_u(path), headers: _headers, body: jsonEncode(body ?? {})),
      };
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

  /// [forgetOn401]: أخطاء الدخول تعني انتهاء الجلسة، إلا في نماذج الدخول والتعديل
  /// حيث تعني «كلمة مرور خاطئة» فلا نُخرج المستخدم.
  Future<void> _run(Future<void> Function() job, {bool forgetOn401 = true}) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await job();
    } on LiveException catch (e) {
      _error = e.message;
      if (forgetOn401 && (e.status == 401 || e.status == 403)) await _forget(keepError: true);
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
      _device = prefs.getString(_deviceKey) ?? '';
      if (_device.isEmpty) {
        final r = Random.secure();
        _device = List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
        await prefs.setString(_deviceKey, _device);
      }
      final g = prefs.getString(_guestNameKey);
      if (g != null && g.isNotEmpty) {
        guestName = g;
      } else {
        await prefs.setString(_guestNameKey, guestName);
      }
    } catch (_) {}
    unawaited(loadStats());
    if (configured) {
      try {
        final data = await _send('GET', '/api/config', timeout: const Duration(seconds: 12));
        final cfg = data['config'];
        if (cfg is Map<String, dynamic>) {
          referText = '${cfg['referText'] ?? ''}'.trim();
          referVisible = cfg['referVisible'] == true;
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

  Future<void> _accept(Map<String, dynamic> data) async {
    _login = '${data['login']}';
    _setUser(data);
    await _save();
  }

  /// زائر: تجربة واحدة قبل التسجيل. يُستدعى تلقائياً عند أول جلسة.
  Future<bool> ensureGuest() async {
    if (_user != null) return true;
    await _run(() async => _accept(await _send('POST', '/api/guest')));
    return _user != null;
  }

  /// حساب جديد (يحوّل الزائر إلى حساب ويحتفظ بجلسته).
  Future<void> signup(String name, String email, String password) => _run(() async {
        await _accept(await _send('POST', '/api/signup',
            body: {'name': name.trim(), 'email': email.trim(), 'password': password, 'device': _device}));
      }, forgetOn401: false);

  /// دخول ببريد وكلمة مرور (جلسة الزائر تنتقل للحساب).
  Future<int> signin(String email, String password) async {
    var moved = 0;
    await _run(() async {
      final data = await _send('POST', '/api/signin',
          body: {'email': email.trim(), 'password': password, 'device': _device});
      moved = (data['moved'] as num?)?.toInt() ?? 0;
      await _accept(data);
    }, forgetOn401: false);
    return moved;
  }

  /// تعديل الاسم أو البريد أو كلمة المرور (البريد وكلمة المرور تحتاج الحالية).
  Future<void> updateAccount({String? name, String? email, String? password, String? newPassword}) =>
      _run(() async {
        _setUser(await _send('POST', '/api/account', body: {
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (password != null) 'password': password,
          if (newPassword != null && newPassword.isNotEmpty) 'newPassword': newPassword,
        }));
      }, forgetOn401: false);

  Future<void> loadStats() async {
    if (!configured) return;
    try {
      final data = await _send('GET', '/api/stats', timeout: const Duration(seconds: 15));
      final st = data['stats'];
      if (st is Map<String, dynamic>) {
        globalStats = st;
        notifyListeners();
      }
    } catch (_) {}
  }

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

  void setReferral(String text, bool visible) {
    referText = text;
    referVisible = visible;
    notifyListeners();
  }

  // ---- لوحة التحكم داخل التطبيق (للمالك والمشرفين) ----
  Future<Map<String, dynamic>> adminGet(String action) =>
      _send('GET', '/api/admin/$action', timeout: const Duration(seconds: 30));

  Future<Map<String, dynamic>> adminPost(String action, Map<String, dynamic> body) =>
      _send('POST', '/api/admin/$action', body: body, timeout: const Duration(seconds: 30));

  Future<void> signOut() async {
    await _forget();
    notifyListeners();
  }

  // ---- الجلسات المحفوظة ----
  Future<List<Map<String, dynamic>>> listSessions() async {
    final data = await _send('GET', '/api/sessions');
    final list = data['sessions'];
    if (list is! List) return const [];
    return [for (final x in list) if (x is Map<String, dynamic>) x];
  }

  Future<Map<String, dynamic>> getSession(String id) async {
    final data = await _send('GET', '/api/sessions/$id');
    final s = data['session'];
    if (s is! Map<String, dynamic>) throw LiveException('الجلسة غير موجودة', 404);
    return s;
  }

  Future<void> saveSession(Map<String, dynamic> session) async {
    await _send('POST', '/api/sessions', body: {'session': session});
  }

  Future<void> deleteSession(String id) async {
    await _send('DELETE', '/api/sessions/$id');
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
      _user = u.withBalance(reply.balanceMicros, u.spentMicros + reply.costMicros);
      notifyListeners();
    }
    return reply;
  }
}
