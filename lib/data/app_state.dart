import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'mock_data.dart';
import 'models.dart';

/// حال الجولة في شريط الجولات: ١ ✓، ٢ نشطة، ٣.
enum RoundProgress { done, active, pending }

/// ChangeNotifier واحد للتطبيق.
///
/// لا يملك: فهرس التبويب (في غلاف app.dart)، ولا بحث المشاريع وتصفيتها
/// وترتيبها (محلية في شاشتها)، ولا مراقبة دورة الحياة، ولا Clipboard.
///
/// الجولة والمتحدث والتقدم تُشتق من المؤشر [cursor] ولا تُخزَّن.
class AppState extends ChangeNotifier {
  AppState({this.stepDuration = const Duration(milliseconds: 900)}) {
    _cursor = _initialCursorFor(_activeProjectId);
  }

  /// خطوة المحاكاة (ثابت نموذج أولي، لا علاقة له بمؤشر «42 ث»).
  final Duration stepDuration;

  // ---- المظهر --------------------------------------------------------------

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  // ---- الحساب (يُقرأ من MockData.account بلا نسخة ثانية) -------------------

  String get userId => MockData.account.userId;
  String get memberSince => MockData.account.memberSince;
  int get points => MockData.account.points;

  // ---- تخطيط صف الأعضاء في الرئيسية ----------------------------------------

  MembersLayout _membersLayout = MembersLayout.row;
  MembersLayout get membersLayout => _membersLayout;

  set membersLayout(MembersLayout value) {
    if (value == _membersLayout) return;
    _membersLayout = value;
    notifyListeners();
  }

  // ---- المشروع النشط -------------------------------------------------------

  String _activeProjectId = MockData.defaultProjectId;
  String get activeProjectId => _activeProjectId;

  Project? get activeProject => MockData.projectById(_activeProjectId);

  /// اختيار المعرّف نفسه أو معرّف مجهول لا يُحدث أثراً.
  void selectProject(String id) {
    if (id == _activeProjectId) return;
    if (MockData.projectById(id) == null) return;
    _stop();
    _activeProjectId = id;
    _cursor = _initialCursorFor(id);
    notifyListeners();
    _ensureRunning();
  }

  // ---- المحاكاة ------------------------------------------------------------

  Timer? _timer;
  int _generation = 0;
  bool _tableVisible = false;
  late int _cursor;

  /// عدد الرسائل المكشوفة. الافتراضي = طول الجولة ١.
  int get cursor => _cursor;

  Discussion? get discussion => MockData.discussionOf(_activeProjectId);

  int get messageCount => discussion?.messages.length ?? 0;

  List<Message> get visibleMessages {
    final s = discussion;
    if (s == null) return const [];
    return s.messages.take(_cursor).toList(growable: false);
  }

  bool get isRunning => _timer != null;

  /// الخلاصة ظاهرة عند اكتمال كل الرسائل.
  bool get summaryVisible => discussion != null && _cursor >= messageCount;

  Summary? get summary => summaryVisible ? discussion!.summary : null;

  double get progress {
    final n = messageCount;
    return n == 0 ? 0 : _cursor / n;
  }

  int get roundCount {
    final s = discussion;
    if (s == null) return 0;
    var maxRound = 0;
    for (final m in s.messages) {
      if (m.roundNumber > maxRound) maxRound = m.roundNumber;
    }
    return maxRound;
  }

  /// الجولة النشطة: جولة الرسالة التالية، وعند الاكتمال آخر جولة.
  int get currentRound {
    final s = discussion;
    if (s == null || s.messages.isEmpty) return 1;
    if (_cursor < s.messages.length) return s.messages[_cursor].roundNumber;
    return s.messages.last.roundNumber;
  }

  RoundProgress roundProgress(int round) {
    final s = discussion;
    if (s == null) return RoundProgress.pending;
    var lastIndex = -1;
    for (var i = 0; i < s.messages.length; i++) {
      if (s.messages[i].roundNumber == round) lastIndex = i;
    }
    if (lastIndex == -1) return RoundProgress.pending;
    if (_cursor > lastIndex) return RoundProgress.done;
    if (round == currentRound) return RoundProgress.active;
    return RoundProgress.pending;
  }

  /// صاحب آخر رسالة مكشوفة. عند الصفر: صاحب أول رسالة. بلا سيناريو: null.
  MemberId? get lastSpeakerId {
    final s = discussion;
    if (s == null || s.messages.isEmpty) return null;
    if (_cursor <= 0) return s.messages.first.senderId;
    final i = _cursor > s.messages.length ? s.messages.length : _cursor;
    return s.messages[i - 1].senderId;
  }

  /// من يظهر في مركز الطاولة. تعود إلى مؤلف الخلاصة فقط حين تظهر.
  MemberId? get centerMemberId {
    final s = discussion;
    if (s == null) return null;
    if (summaryVisible) return s.summary.authorId;
    return lastSpeakerId;
  }

  int _initialCursorFor(String projectId) {
    final s = MockData.discussionOf(projectId);
    if (s == null) return 0;
    var n = 0;
    for (final m in s.messages) {
      if (m.roundNumber == 1) n++;
    }
    return n;
  }

  /// يستدعيه الغلاف: ظهور تبويب الطاولة والتطبيق في المقدمة معاً.
  void setTableVisible(bool visible) {
    if (visible == _tableVisible) return;
    _tableVisible = visible;
    if (visible) {
      _ensureRunning();
    } else {
      _stop(); // يوقف ولا يصفّر المؤشر.
    }
    notifyListeners();
  }

  /// «إعادة»: المؤشر إلى الصفر. لا تمس المحفوظات ولا الجلسة المختارة.
  void restartSimulation() {
    _stop();
    _cursor = 0;
    notifyListeners();
    _ensureRunning();
  }

  /// «انتقل إلى الخلاصة»: يكمل السيناريو فوراً. التمرير مسؤولية الواجهة.
  void jumpToSummary() {
    if (discussion == null) return;
    _stop();
    _cursor = messageCount;
    notifyListeners();
  }

  void _ensureRunning() {
    if (!_tableVisible) return;
    if (discussion == null) return;
    if (_cursor >= messageCount) return;
    if (_timer != null) return; // لا مؤقّتين ولا إعادة مهلة.
    final gen = _generation;
    _timer = Timer(stepDuration, () {
      if (gen != _generation) return; // نبضة يتيمة من جيل قديم.
      _timer = null;
      _cursor++;
      notifyListeners();
      _ensureRunning();
    });
  }

  void _stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
  }

  // ---- المحفوظات (مفتاحها معرّف المشروع) ------------------------------------

  final Map<String, Summary> _saved = {};

  /// داخل جلسة التشغيل فقط؛ لا تبقى بعد إغلاق التطبيق.
  Map<String, Summary> get savedSummaries => Map.unmodifiable(_saved);

  bool isSaved(String projectId) => _saved.containsKey(projectId);

  /// الحفظ الثاني يحدّث السجل نفسه. الخلاصة غير المتاحة لا تنشئ سجلاً.
  bool saveSummary() {
    final s = summary;
    if (s == null) return false;
    _saved[_activeProjectId] = s;
    notifyListeners();
    return true;
  }

  // ---- المختبر -------------------------------------------------------------

  String _selectedEvaluationId = MockData.defaultEvaluationId;
  String get selectedEvaluationId => _selectedEvaluationId;

  Evaluation get selectedEvaluation =>
      MockData.evaluationById(_selectedEvaluationId) ??
      MockData.evaluations.first;

  /// معرّف مجهول لا يُحدث أثراً. المؤشرات الأربعة لا تتأثر.
  void selectEvaluation(String id) {
    if (id == _selectedEvaluationId) return;
    if (MockData.evaluationById(id) == null) return;
    _selectedEvaluationId = id;
    notifyListeners();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}

/// يمرّر [AppState] عبر InheritedNotifier.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  /// يسجّل اعتماداً: يُعاد بناء المستدعي مع كل تغيّر.
  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope غير موجود فوق هذا السياق');
    return scope!.notifier!;
  }

  /// بلا اعتماد: للاستدعاء داخل المعالجات.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope غير موجود فوق هذا السياق');
    return scope!.notifier!;
  }
}
