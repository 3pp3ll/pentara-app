import 'dart:math';

import 'package:flutter/foundation.dart';

import '../theme/app_colors.dart';
import 'live_api.dart';

/// نوع المخرج المطلوب من الطاولة.
enum LiveOutput {
  text('نصوص وتحليل', 'نصوص'),
  plan('خطة عمل', 'خطط'),
  research('بحث ودراسة', 'بحثية'),
  appIdea('فكرة تطبيق', 'برمجية'),
  web('صفحة ويب', 'ويب');

  const LiveOutput(this.label, this.category);
  final String label;

  /// اسم الفئة في ملخص المشاريع والمختبر.
  final String category;
}

enum LivePhase { idle, round1, round2, summary, revising, done, failed }

/// رسالة عضو في الجلسة الحية.
class LiveEntry {
  LiveEntry({required this.seat, required this.round});
  final MemberId seat;
  final int round;
  String text = '';
  String? error;
  bool pending = true;

  Map<String, dynamic> toJson() => {'seat': seat.name, 'round': round, 'text': text, 'error': error};

  static LiveEntry fromJson(Map<String, dynamic> j) {
    final seat = MemberId.values.firstWhere((m) => m.name == j['seat'], orElse: () => MemberId.engineer);
    return LiveEntry(seat: seat, round: (j['round'] as num?)?.toInt() ?? 1)
      ..text = '${j['text'] ?? ''}'
      ..error = j['error'] as String?
      ..pending = false;
  }
}

/// ملف مرفق: اسمه ونصه (حد أقصى للطول حتى لا ترتفع التكلفة).
class LiveAttachment {
  const LiveAttachment({required this.name, required this.text});
  final String name;
  final String text;

  static const int maxChars = 12000;
  static const int maxTotal = 30000;

  Map<String, dynamic> toJson() => {'name': name, 'text': text};
  static LiveAttachment fromJson(Map<String, dynamic> j) =>
      LiveAttachment(name: '${j['name'] ?? 'ملف'}', text: '${j['text'] ?? ''}');
}

/// طلب تعديل من المستخدم بعد الخلاصة، ورد الرئيس عليه.
class LiveRevision {
  LiveRevision({required this.request, this.summary = '', this.pending = true, this.error});
  final String request;
  String summary;
  bool pending;
  String? error;

  Map<String, dynamic> toJson() => {'request': request, 'summary': summary, 'error': error};
  static LiveRevision fromJson(Map<String, dynamic> j) => LiveRevision(
        request: '${j['request'] ?? ''}',
        summary: '${j['summary'] ?? ''}',
        pending: false,
        error: j['error'] as String?,
      );
}

const Map<MemberId, String> _roles = {
  MemberId.engineer:
      'أنت «المهندس»: تركّز على البنية والتنظيم وتقسيم العمل إلى أجزاء واضحة.',
  MemberId.practical:
      'أنت «العملي»: تركّز على خطوات التنفيذ الفعلية بالترتيب والوقت والموارد.',
  MemberId.analyst:
      'أنت «المحلل»: تركّز على الأرقام والسوق والتكاليف والبيانات، وتذكر افتراضاتك.',
  MemberId.challenger:
      'أنت «المتحدّي»: تراجع المخاطر ونقاط الضعف والاعتراضات بصراحة ومن دون مجاملة.',
  MemberId.auditor:
      'أنت «المدقق»: تتحقق من صحة المعلومات والدقة وتنبّه لأي خطأ أو مبالغة.',
};

const List<MemberId> memberSeats = [
  MemberId.engineer,
  MemberId.practical,
  MemberId.analyst,
  MemberId.challenger,
  MemberId.auditor,
];

const String _house =
    'أنت عضو في «طاولة بنتارا»: مجلس من خمسة عقول يناقش فكرة المستخدم ويرأسه رئيس الجلسة. '
    'اكتب بالعربية الفصحى المبسطة، بإيجاز ووضوح، بلا مقدمات ولا مجاملات. '
    'لا تذكر اسمك كنموذج أو اسم شركتك.';

String _newId() {
  final r = Random();
  final t = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final s = List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
  return '$t$s';
}

/// جلسة حقيقية: جولة آراء، ثم جولة تصحيح، ثم خلاصة الرئيس، ثم تعديلات.
/// تُحفظ في السيرفر بعد كل خلاصة أو تعديل، وتُفتح لاحقاً من «المشاريع».
class LiveSession extends ChangeNotifier {
  LiveSession({LiveController? api, String? id})
      : _api = api ?? LiveController.instance,
        id = id ?? _newId();

  final LiveController _api;
  final String id;

  DateTime createdAt = DateTime.now();
  String idea = '';
  LiveOutput output = LiveOutput.text;
  LivePhase phase = LivePhase.idle;
  final List<LiveEntry> entries = [];
  final List<String> notes = [];

  /// ملفات ومصادر يرفقها المستخدم مع الفكرة (نصوص تُقرأ مع الطلب).
  final List<LiveAttachment> attachments = [];
  String sources = '';
  final List<LiveRevision> revisions = [];
  String summary = '';
  bool summaryCut = false;
  String? error;
  int costMicros = 0;
  bool saved = false;

  /// جرت في هذا التشغيل (لا مفتوحة من المحفوظات): الزائر ينسخ خلاصتها مرة واحدة.
  bool ranHere = false;
  bool guestCopied = false;
  bool _disposed = false;

  String get title {
    final t = idea.trim().split('\n').first.trim();
    if (t.isEmpty) return 'جلسة جديدة';
    return t.length > 48 ? '${t.substring(0, 48)}…' : t;
  }

  /// آخر خلاصة معتمدة (بعد آخر تعديل ناجح).
  String get latestSummary {
    for (final r in revisions.reversed) {
      if (!r.pending && r.error == null && r.summary.isNotEmpty) return r.summary;
    }
    return summary;
  }

  bool get running =>
      phase == LivePhase.round1 ||
      phase == LivePhase.round2 ||
      phase == LivePhase.summary ||
      phase == LivePhase.revising;

  bool get discussing => phase == LivePhase.round1 || phase == LivePhase.round2;

  String get phaseLabel => switch (phase) {
        LivePhase.idle => '',
        LivePhase.round1 => 'الجولة ١: الأعضاء يكتبون آراءهم',
        LivePhase.round2 => 'الجولة ٢: التصحيح والاتفاق',
        LivePhase.summary => 'رئيس الجلسة يكتب الخلاصة',
        LivePhase.revising => 'رئيس الجلسة يطبّق تعديلك',
        LivePhase.done => 'اكتملت الجلسة',
        LivePhase.failed => 'توقفت الجلسة',
      };

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ---- حفظ واسترجاع ---------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'v': 1,
        'title': title,
        'idea': idea,
        'output': output.name,
        'createdAt': createdAt.toIso8601String(),
        'status': phase == LivePhase.done ? 'done' : 'stopped',
        'entries': [for (final e in entries.where((e) => !e.pending)) e.toJson()],
        'notes': notes,
        'sources': sources,
        'attachments': [for (final a in attachments) a.toJson()],
        'summary': summary,
        'summaryCut': summaryCut,
        'revisions': [for (final r in revisions.where((r) => !r.pending)) r.toJson()],
        'costMicros': costMicros,
      };

  static LiveSession fromJson(Map<String, dynamic> j) {
    final s = LiveSession(id: '${j['id']}');
    s.idea = '${j['idea'] ?? ''}';
    s.output = LiveOutput.values.firstWhere((o) => o.name == j['output'], orElse: () => LiveOutput.plan);
    s.createdAt = DateTime.tryParse('${j['createdAt']}') ?? DateTime.now();
    for (final e in (j['entries'] as List? ?? const [])) {
      if (e is Map<String, dynamic>) s.entries.add(LiveEntry.fromJson(e));
    }
    s.sources = '${j['sources'] ?? ''}';
    for (final a in (j['attachments'] as List? ?? const [])) {
      if (a is Map<String, dynamic>) s.attachments.add(LiveAttachment.fromJson(a));
    }
    for (final n in (j['notes'] as List? ?? const [])) {
      s.notes.add('$n');
    }
    s.summary = '${j['summary'] ?? ''}';
    s.summaryCut = j['summaryCut'] == true;
    for (final r in (j['revisions'] as List? ?? const [])) {
      if (r is Map<String, dynamic>) s.revisions.add(LiveRevision.fromJson(r));
    }
    s.costMicros = (j['costMicros'] as num?)?.toInt() ?? 0;
    s.phase = s.summary.isNotEmpty ? LivePhase.done : LivePhase.failed;
    s.saved = true;
    return s;
  }

  Future<void> save() async {
    try {
      await _api.saveSession(toJson());
      saved = true;
      LiveHub.instance.upsert(this);
      _notify();
    } catch (_) {
      // الحفظ يُعاد مع التعديل التالي؛ لا نوقف المستخدم.
    }
  }

  // ---- النقاش -----------------------------------------------------------------

  String get _task {
    final b = StringBuffer('نوع المخرج المطلوب: ${output.label}.\n\nفكرة المستخدم:\n${idea.trim()}');
    if (sources.trim().isNotEmpty) b.write('\n\nمصادر ذكرها المستخدم (روابط أو مراجع):\n${sources.trim()}');
    if (attachments.isNotEmpty) {
      b.write('\n\nملفات أرفقها المستخدم (اعتمد عليها):');
      for (final a in attachments) {
        b.write('\n--- ${a.name} ---\n${a.text}');
      }
    }
    return b.toString();
  }

  String get _notesBlock => notes.isEmpty
      ? ''
      : '\n\nمداخلات المستخدم أثناء النقاش (التزم بها):\n${notes.map((n) => '- $n').join('\n')}';

  /// مداخلة من المستخدم أثناء النقاش: تدخل في الجولة التالية والخلاصة.
  void addNote(String text) {
    final t = text.trim();
    if (t.isEmpty || !running) return;
    notes.add(t);
    _notify();
  }

  Future<void> _seat(LiveEntry e, List<Map<String, String>> messages, String kind) async {
    try {
      final r = await _api.speak(seat: e.seat.name, kind: kind, messages: messages);
      e.text = r.text.isEmpty ? '(لم يصل رد)' : r.text;
      e.error = null; // وصل الرد ولو بعد الإيقاف: يُحتفظ به ولا يُعاد طلبه
      costMicros += r.costMicros;
    } on LiveException catch (err) {
      e.error = err.message;
    } catch (_) {
      e.error = 'تعذّر الرد';
    }
    e.pending = false;
    _notify();
  }

  String _transcript(int round) {
    final b = StringBuffer();
    for (final e in entries.where((x) => x.round == round && x.error == null && !x.pending)) {
      b.writeln('— ${seatTitle(e.seat)}:');
      b.writeln(e.text);
      b.writeln();
    }
    return b.toString();
  }

  static String seatTitle(MemberId id) => switch (id) {
        MemberId.chair => 'رئيس الجلسة',
        MemberId.engineer => 'المهندس',
        MemberId.practical => 'العملي',
        MemberId.analyst => 'المحلل',
        MemberId.challenger => 'المتحدّي',
        MemberId.auditor => 'المدقق',
      };

  bool _stopped = false;

  /// إيقاف الجلسة: ما وصل يبقى محفوظاً، و«استمرار» يكمل من نفس النقطة.
  void stop() {
    if (!running) return;
    _stopped = true;
    for (final e in entries.where((e) => e.pending)) {
      e.pending = false;
      e.error = 'أُوقف قبل الرد';
    }
    for (final r in revisions.where((r) => r.pending)) {
      r.pending = false;
      r.error = 'أُوقف';
    }
    phase = LivePhase.failed;
    error = 'أوقفت الجلسة. اضغط «استمرار» لتكمل من نفس النقطة.';
    _notify();
    save();
  }

  /// يمكن الاستمرار: جلسة متوقفة (إيقاف، انقطاع، رد متعذّر) لم تُكتب خلاصتها بعد.
  bool get canResume =>
      phase == LivePhase.failed && summary.isEmpty && idea.trim().length >= 10 && entries.isNotEmpty;

  List<Map<String, String>> _memberMsgs(LiveEntry e) => [
        {'role': 'system', 'content': '$_house\n${_roles[e.seat]}'},
        {
          'role': 'user',
          'content': '$_task\n\nاكتب رأيك من زاويتك في 200 كلمة كحد أقصى، بنقاط مرتبة.',
        },
      ];

  List<Map<String, String>> _critiqueMsgs(LiveEntry e, String round1) => [
        {'role': 'system', 'content': '$_house\n${_roles[e.seat]}'},
        {
          'role': 'user',
          'content': '$_task$_notesBlock\n\nآراء الأعضاء في الجولة الأولى:\n$round1\n'
              'من زاويتك: ما الذي توافق عليه، وما الخطأ أو الناقص الذي يجب تصحيحه؟ '
              'في 100 كلمة كحد أقصى. إن لم يكن لديك تصحيح فاكتب «أوافق» مع سبب قصير.',
        },
      ];

  /// إعادة رد عضو تعذّر (انقطاع أو إيقاف).
  void _reset(LiveEntry e) {
    e.error = null;
    e.text = '';
    e.pending = true;
  }

  Future<void> start() async {
    if (running || idea.trim().length < 10) return;
    entries.clear();
    notes.clear();
    revisions.clear();
    summary = '';
    summaryCut = false;
    error = null;
    costMicros = 0;
    createdAt = DateTime.now();
    ranHere = true;
    entries.addAll([for (final s in memberSeats) LiveEntry(seat: s, round: 1)]);
    await _run();
  }

  /// استمرار جلسة متوقفة: يعيد الردود المتعذّرة فقط، ثم يكمل ما بعدها.
  Future<void> resume() async {
    if (!canResume) return;
    await _run();
  }

  Future<void> _run() async {
    _stopped = false;
    error = null;

    // الجولة ١: كل عضو يكتب رأيه بالتوازي (أو من تعذّر ردّه فقط عند الاستمرار).
    final r1 = entries.where((e) => e.round == 1).toList();
    final todo1 = r1.where((e) => e.error != null || e.text.isEmpty).toList();
    if (todo1.isNotEmpty) {
      phase = LivePhase.round1;
      for (final e in todo1) {
        _reset(e);
      }
      _notify();
      await Future.wait([for (final e in todo1) _seat(e, _memberMsgs(e), 'member')]);
      if (_disposed || _stopped) return;
    }
    final ok1 = r1.where((e) => e.error == null).length;
    if (ok1 < 2) {
      phase = LivePhase.failed;
      error = r1.firstWhere((e) => e.error != null, orElse: () => r1.first).error ??
          'لم تصل ردود كافية';
      _notify();
      await save();
      return;
    }

    // الجولة ٢: كل عضو يقرأ آراء الآخرين ويصحح ويتفق.
    final round1 = _transcript(1);
    final have2 = {for (final e in entries.where((e) => e.round == 2)) e.seat};
    for (final e in r1.where((x) => x.error == null && !have2.contains(x.seat))) {
      entries.add(LiveEntry(seat: e.seat, round: 2));
    }
    final todo2 = entries.where((e) => e.round == 2 && (e.error != null || e.text.isEmpty)).toList();
    if (todo2.isNotEmpty) {
      phase = LivePhase.round2;
      for (final e in todo2) {
        _reset(e);
      }
      _notify();
      await Future.wait([for (final e in todo2) _seat(e, _critiqueMsgs(e, round1), 'critique')]);
      if (_disposed || _stopped) return;
    }

    await writeSummary();
  }

  /// الخلاصة: رئيس الجلسة يجمع كل شيء. تُعاد وحدها إن تعذّرت.
  Future<void> writeSummary() async {
    if (_disposed || entries.isEmpty) return;
    final round1 = _transcript(1);
    error = null;
    _stopped = false;
    phase = LivePhase.summary;
    _notify();
    try {
      final r = await _api.speak(
        seat: MemberId.chair.name,
        kind: 'chair',
        messages: [
          {
            'role': 'system',
            'content': '$_house\nأنت «رئيس الجلسة»: تقيّم النقاش وتكتب الخلاصة النهائية الموحّدة '
                'التي يعتمدها المستخدم. اعتمد ما اتفق عليه الأعضاء وصحّح ما ثبت خطؤه.',
          },
          {
            'role': 'user',
            'content': '$_task$_notesBlock\n\nالجولة الأولى:\n$round1\nجولة التصحيح:\n${_transcript(2)}\n'
                'اكتب الخلاصة النهائية بهذه الأقسام وبعناوين واضحة: '
                'الخلاصة في سطرين، الخطة أو المحتوى الأساسي، الأرقام والتكاليف التقديرية، '
                'المخاطر وطريقة تجنبها، الخطوة التالية. لا تكتب كوداً.'
                '${output == LiveOutput.web ? ' ولأن المخرج صفحة ويب: اكتب أقسام الصفحة بالترتيب ونص كل قسم جاهزاً للنشر.' : ''}',
          },
        ],
      );
      if (_stopped) return;
      summary = r.text;
      summaryCut = r.cut;
      costMicros += r.costMicros;
      phase = LivePhase.done;
    } on LiveException catch (err) {
      error = err.message;
      phase = LivePhase.failed;
    } catch (_) {
      error = 'تعذّرت كتابة الخلاصة';
      phase = LivePhase.failed;
    }
    _notify();
    if (phase == LivePhase.done) await save();
  }

  /// طلب تعديل على الخلاصة: الرئيس يعيد كتابتها كاملة مع التعديل.
  Future<void> revise(String request) async {
    final req = request.trim();
    if (req.isEmpty || running || latestSummary.isEmpty) return;
    final rev = LiveRevision(request: req);
    final base = latestSummary;
    revisions.add(rev);
    error = null;
    _stopped = false;
    phase = LivePhase.revising;
    _notify();
    try {
      final r = await _api.speak(
        seat: MemberId.chair.name,
        kind: 'chair',
        messages: [
          {
            'role': 'system',
            'content': '$_house\nأنت «رئيس الجلسة». المستخدم يطلب تعديلاً على الخلاصة المعتمدة. '
                'طبّق التعديل بدقة، وأعد كتابة الخلاصة كاملة بنفس الأقسام، ولا تحذف ما لم يُطلب حذفه.',
          },
          {
            'role': 'user',
            'content': '$_task\n\nالخلاصة الحالية:\n$base\n\nطلب التعديل:\n$req',
          },
        ],
      );
      if (_stopped) return;
      rev.summary = r.text;
      costMicros += r.costMicros;
    } on LiveException catch (err) {
      rev.error = err.message;
    } catch (_) {
      rev.error = 'تعذّر تطبيق التعديل';
    }
    rev.pending = false;
    phase = LivePhase.done;
    _notify();
    if (rev.error == null) await save();
  }
}

/// ملخص جلسة محفوظة (لقائمة المشاريع).
class SessionMeta {
  const SessionMeta({
    required this.id,
    required this.title,
    required this.output,
    required this.createdAt,
    required this.costMicros,
    required this.status,
  });

  factory SessionMeta.fromJson(Map<String, dynamic> j) => SessionMeta(
        id: '${j['id']}',
        title: '${j['title'] ?? 'جلسة'}',
        output: LiveOutput.values.firstWhere((o) => o.name == j['output'], orElse: () => LiveOutput.plan),
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        costMicros: (j['costMicros'] as num?)?.toInt() ?? 0,
        status: '${j['status'] ?? 'done'}',
      );

  final String id;
  final String title;
  final LiveOutput output;
  final DateTime createdAt;
  final int costMicros;
  final String status;
}

/// الجلسة الحالية في تبويب الطاولة + قائمة الجلسات المحفوظة.
class LiveHub extends ChangeNotifier {
  LiveHub._();
  static final LiveHub instance = LiveHub._();

  LiveSession _current = LiveSession();
  LiveSession get current => _current;

  List<SessionMeta> sessions = const [];
  bool loading = false;
  String? error;

  // الجلسة السابقة لا تُتلف هنا: قد تكون واجهة ما زالت تستمع لها حتى إعادة البناء،
  // وإن كانت تعمل فستكمل وتُحفظ في الخلفية.
  void _swap(LiveSession s) {
    _current = s;
    notifyListeners();
  }

  /// جلسة جديدة فارغة (إن كانت الحالية تعمل تبقى تعمل في الخلفية حتى تُحفظ).
  void newSession() => _swap(LiveSession());

  Future<void> loadList() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final rows = await LiveController.instance.listSessions();
      sessions = [for (final r in rows) SessionMeta.fromJson(r)]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } on LiveException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'تعذّر تحميل الجلسات';
    }
    loading = false;
    notifyListeners();
  }

  /// يفتح جلسة محفوظة في تبويب الطاولة. يعيد false إن تعذّر.
  Future<bool> open(String id) async {
    if (_current.id == id) return true;
    try {
      final j = await LiveController.instance.getSession(id);
      _swap(LiveSession.fromJson(j));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// تحديث القائمة محلياً بعد الحفظ بدل إعادة التحميل من السيرفر.
  void upsert(LiveSession s) {
    final meta = SessionMeta(
      id: s.id,
      title: s.title,
      output: s.output,
      createdAt: s.createdAt,
      costMicros: s.costMicros,
      status: s.phase == LivePhase.done ? 'done' : 'stopped',
    );
    sessions = [meta, ...sessions.where((x) => x.id != s.id)];
    notifyListeners();
  }

  Future<void> delete(String id) async {
    try {
      await LiveController.instance.deleteSession(id);
      sessions = sessions.where((s) => s.id != id).toList();
      if (_current.id == id) _swap(LiveSession());
      notifyListeners();
    } catch (_) {}
  }
}
