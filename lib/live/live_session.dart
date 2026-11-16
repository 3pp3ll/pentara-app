import 'package:flutter/foundation.dart';

import '../theme/app_colors.dart';
import 'live_api.dart';

/// نوع المخرج المطلوب من الطاولة.
enum LiveOutput {
  plan('خطة عمل'),
  research('بحث ودراسة'),
  appIdea('فكرة تطبيق');

  const LiveOutput(this.label);
  final String label;
}

enum LivePhase { idle, round1, round2, summary, done, failed }

/// رسالة عضو في الجلسة الحية.
class LiveEntry {
  LiveEntry({required this.seat, required this.round});
  final MemberId seat;
  final int round;
  String text = '';
  String? error;
  bool pending = true;
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

/// جلسة حقيقية: جولة آراء، ثم جولة تصحيح، ثم خلاصة الرئيس.
class LiveSession extends ChangeNotifier {
  LiveSession({LiveController? api}) : _api = api ?? LiveController.instance;

  final LiveController _api;

  String idea = '';
  LiveOutput output = LiveOutput.plan;
  LivePhase phase = LivePhase.idle;
  final List<LiveEntry> entries = [];
  String summary = '';
  bool summaryCut = false;
  String? error;
  int costMicros = 0;
  bool _disposed = false;

  bool get running =>
      phase == LivePhase.round1 || phase == LivePhase.round2 || phase == LivePhase.summary;

  String get phaseLabel => switch (phase) {
        LivePhase.idle => '',
        LivePhase.round1 => 'الجولة ١: الأعضاء يكتبون آراءهم',
        LivePhase.round2 => 'الجولة ٢: التصحيح والاتفاق',
        LivePhase.summary => 'رئيس الجلسة يكتب الخلاصة',
        LivePhase.done => 'اكتملت الجلسة',
        LivePhase.failed => 'توقفت الجلسة',
      };

  /// تعذّرت الخلاصة بعد اكتمال الجولات: يمكن إعادتها وحدها.
  bool get canRetrySummary =>
      phase == LivePhase.failed &&
      entries.where((e) => e.round == 1 && e.error == null && !e.pending).length >= 2;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String get _task =>
      'نوع المخرج المطلوب: ${output.label}.\n\nفكرة المستخدم:\n${idea.trim()}';

  Future<void> _seat(LiveEntry e, List<Map<String, String>> messages, String kind) async {
    try {
      final r = await _api.speak(seat: e.seat.name, kind: kind, messages: messages);
      e.text = r.text.isEmpty ? '(لم يصل رد)' : r.text;
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
    for (final e in entries.where((x) => x.round == round && x.error == null)) {
      b.writeln('— ${_title(e.seat)}:');
      b.writeln(e.text);
      b.writeln();
    }
    return b.toString();
  }

  static String _title(MemberId id) => switch (id) {
        MemberId.chair => 'رئيس الجلسة',
        MemberId.engineer => 'المهندس',
        MemberId.practical => 'العملي',
        MemberId.analyst => 'المحلل',
        MemberId.challenger => 'المتحدّي',
        MemberId.auditor => 'المدقق',
      };

  Future<void> start() async {
    if (running || idea.trim().length < 10) return;
    entries.clear();
    summary = '';
    summaryCut = false;
    error = null;
    costMicros = 0;

    // الجولة ١: كل عضو يكتب رأيه بالتوازي.
    phase = LivePhase.round1;
    final r1 = [for (final s in memberSeats) LiveEntry(seat: s, round: 1)];
    entries.addAll(r1);
    _notify();
    await Future.wait([
      for (final e in r1)
        _seat(e, [
          {'role': 'system', 'content': '$_house\n${_roles[e.seat]}'},
          {
            'role': 'user',
            'content': '$_task\n\nاكتب رأيك من زاويتك في 200 كلمة كحد أقصى، بنقاط مرتبة.',
          },
        ], 'member'),
    ]);
    if (_disposed) return;
    final ok1 = r1.where((e) => e.error == null).length;
    if (ok1 < 2) {
      phase = LivePhase.failed;
      error = r1.firstWhere((e) => e.error != null, orElse: () => r1.first).error ??
          'لم تصل ردود كافية';
      _notify();
      return;
    }

    // الجولة ٢: كل عضو يقرأ آراء الآخرين ويصحح ويتفق.
    phase = LivePhase.round2;
    final round1 = _transcript(1);
    final r2 = [
      for (final e in r1.where((x) => x.error == null)) LiveEntry(seat: e.seat, round: 2),
    ];
    entries.addAll(r2);
    _notify();
    await Future.wait([
      for (final e in r2)
        _seat(e, [
          {'role': 'system', 'content': '$_house\n${_roles[e.seat]}'},
          {
            'role': 'user',
            'content': '$_task\n\nآراء الأعضاء في الجولة الأولى:\n$round1\n'
                'من زاويتك: ما الذي توافق عليه، وما الخطأ أو الناقص الذي يجب تصحيحه؟ '
                'في 100 كلمة كحد أقصى. إن لم يكن لديك تصحيح فاكتب «أوافق» مع سبب قصير.',
          },
        ], 'critique'),
    ]);
    if (_disposed) return;

    await writeSummary();
  }

  /// الخلاصة: رئيس الجلسة يجمع كل شيء. تُعاد وحدها إن تعذّرت.
  Future<void> writeSummary() async {
    if (_disposed || entries.isEmpty) return;
    final round1 = _transcript(1);
    error = null;
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
            'content': '$_task\n\nالجولة الأولى:\n$round1\nجولة التصحيح:\n${_transcript(2)}\n'
                'اكتب الخلاصة النهائية بهذه الأقسام وبعناوين واضحة: '
                'الخلاصة في سطرين، الخطة أو المحتوى الأساسي، الأرقام والتكاليف التقديرية، '
                'المخاطر وطريقة تجنبها، الخطوة التالية. لا تكتب كوداً.',
          },
        ],
      );
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
  }
}
