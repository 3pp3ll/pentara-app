import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_state.dart';
import 'data/mock_data.dart';
import 'data/models.dart';
import 'screens/home_screen.dart';
import 'screens/projects_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/app_typography.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/gold_button.dart';
import 'widgets/member_avatar.dart';
import 'widgets/member_icons.dart';

/// جذر تطبيق بنتارا.
///
/// ينشئ [AppState] مرة واحدة ويتخلّص منه. يستمع لتغيّر المظهر وحده قبل
/// setState، فلا تعيد نبضات المحاكاة بناء MaterialApp عند كل خطوة. وتُحقن
/// الحالة داخل builder فتراها كل المسارات.
class PentaraApp extends StatefulWidget {
  const PentaraApp({super.key});

  @override
  State<PentaraApp> createState() => _PentaraAppState();
}

class _PentaraAppState extends State<PentaraApp> {
  late final AppState _app;
  late ThemeMode _mode;

  @override
  void initState() {
    super.initState();
    _app = AppState();
    _mode = _app.themeMode;
    _app.addListener(_onAppChanged);
  }

  void _onAppChanged() {
    if (_app.themeMode == _mode) return;
    setState(() => _mode = _app.themeMode);
  }

  @override
  void dispose() {
    _app.removeListener(_onAppChanged);
    _app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بنتارا',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _mode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      themeAnimationCurve: Curves.easeOutCubic,
      builder: (context, child) => AppStateScope(
        state: _app,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _Shell(),
    );
  }
}

const int _homeTabIndex = 0;
const int _tableTabIndex = 1;
const int _projectsTabIndex = 2;
const int _accountTabIndex = 4;

/// عنوان التبويب المؤقت (المختبر فقط حالياً).
const List<String> _tabTitles = [
  'الرئيسية',
  'الطاولة',
  'المشاريع',
  'المختبر',
  'حسابي',
];

/// غلاف التنقل: يملك فهرس التبويب ويراقب دورة حياة التطبيق، ويبلّغ
/// [AppState] بظهور الطاولة فقط (ظهور التبويب والتطبيق في المقدمة شرطان).
/// وهو وحده يختار المشروع ويبدّل التبويب ويعرض التنبيهات على سقالته
/// الواحدة، فيظهر التنبيه فوق الشريط السفلي.
/// كل تبويب يُلفّ بـ TickerMode فلا يستمر نبض الأقراص في تبويب مخفي
/// (IndexedStack يُبقيها مركّبة). لا مفتاح متغيّر، فتبقى حالة البحث والتمرير.
// TODO(batch-5): تُستبدل الشاشات المؤقتة (الطاولة والمختبر وحسابي).
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> with WidgetsBindingObserver {
  int _index = 0;
  bool _resumed = true;
  AppState? _app;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppStateScope.read(context);
    _syncTableVisibility();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncTableVisibility();
  }

  void _syncTableVisibility() {
    _app?.setTableVisible(_index == _tableTabIndex && _resumed);
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _syncTableVisibility();
  }

  /// تنبيه بألوان صريحة (لا snackBarTheme في الثيم): خلفية ink ونص bg.
  void _notify(String message) {
    final c = context.colors;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 3),
        content: Text(
          message,
          style: AppTypography.label.copyWith(color: c.bg),
        ),
      ),
    );
  }

  /// «مشروع جديد»: يختار السيناريو التجريبي الافتراضي ويفتح الطاولة.
  /// لا يعيد المحاكاة ولا يَعِد بموضع معيّن لها.
  void _newProject() {
    _app?.selectProject(MockData.defaultProjectId);
    _select(_tableTabIndex);
    _notify('يُفتح السيناريو التجريبي المُعدّ مسبقاً');
  }

  /// الضغط على بطاقة مشروع: يختار معرّفه ثم يفتح الطاولة.
  void _openProject(String id) {
    _app?.selectProject(id);
    _select(_tableTabIndex);
  }

  void _showNoNotifications() {
    _notify('لا توجد إشعارات في الوضع التجريبي');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _screen(int i) {
    return switch (i) {
      _homeTabIndex => HomeScreen(
          onNewProject: _newProject,
          onOpenProject: _openProject,
          onNotifications: _showNoNotifications,
        ),
      _projectsTabIndex => ProjectsScreen(onOpenProject: _openProject),
      _tableTabIndex => const _TempTable(),
      _accountTabIndex => const _TempAccount(),
      _ => _TempTitleOnly(title: _tabTitles[i]),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = c.brightness == Brightness.dark;

    final overlay =
        (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: c.surface,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < _tabTitles.length; i++)
                TickerMode(
                  enabled: i == _index,
                  child: _screen(i),
                ),
            ],
          ),
        ),
        // SafeArea السفلية داخل BottomNav مرة واحدة.
        bottomNavigationBar: BottomNav(
          currentIndex: _index,
          onTap: _select,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// شاشات مؤقتة تُستبدل في الدفعات التالية
// ---------------------------------------------------------------------------

class _TempTitleOnly extends StatelessWidget {
  const _TempTitleOnly({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: AppTypography.title.copyWith(color: c.ink),
      ),
    );
  }
}

/// عرض مؤقت لحالة المحاكاة للتحقق من الطبقة. يقرأ الجالبات العامة فقط،
/// ويُعاد بناؤه مع كل نبضة دون غيره. مشروع بلا نقاش (messageCount == 0)
/// يعرض رسالة عدم التوفر ولا يستعير نقاش مشروع آخر.
// TODO(batch-5): يُحذف مع بناء table_screen.dart.
class _TempTable extends StatelessWidget {
  const _TempTable();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final app = AppStateScope.of(context);
    final project = app.activeProject;
    final hasDiscussion = app.messageCount > 0;
    final speakerId = app.centerMemberId;
    final speaker = speakerId == null ? null : MockData.memberOf(speakerId);

    final status = app.summaryVisible
        ? 'الخلاصة ظاهرة'
        : (app.isRunning ? 'المحاكاة تعمل' : 'المحاكاة متوقفة');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.all(16),
          decoration: ShapeDecoration(
            color: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: c.border),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                project?.name ?? '',
                textAlign: TextAlign.center,
                style: AppTypography.title.copyWith(color: c.ink),
              ),
              const SizedBox(height: 12),
              if (!hasDiscussion)
                Text(
                  'لا يوجد سيناريو تجريبي مُعدّ لهذا المشروع',
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(color: c.inkMuted),
                )
              else ...[
                if (speaker != null) ...[
                  MemberAvatar(
                    member: speaker,
                    size: 64,
                    isSpeaking: app.isRunning,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MemberIcon(
                        symbol: speaker.symbol,
                        size: 18,
                        color: c.memberName(speaker.id),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        speaker.title,
                        style: AppTypography.bodyStrong
                            .copyWith(color: c.memberName(speaker.id)),
                      ),
                    ],
                  ),
                ] else
                  Text(
                    'لا يوجد متحدث',
                    style: AppTypography.label.copyWith(color: c.inkMuted),
                  ),
                const SizedBox(height: 8),
                Text(
                  toArabicDigits(
                    'الجولة ${app.currentRound} — الرسائل ${app.cursor} من ${app.messageCount}',
                  ),
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(color: c.inkMuted),
                ),
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: AppTypography.label.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GoldButton.secondary(
                      label: 'إعادة',
                      onTap: app.restartSimulation,
                    ),
                    GoldButton.secondary(
                      label: 'الخلاصة',
                      onTap: app.jumpToSummary,
                    ),
                    GoldButton.secondary(
                      label: 'حفظ',
                      onTap: app.saveSummary,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// TODO(batch-5): يُستبدل بزر المظهر الحقيقي في account_screen.dart.
class _TempAccount extends StatelessWidget {
  const _TempAccount();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = c.brightness == Brightness.dark;
    final label =
        isDark ? 'التبديل إلى الوضع الفاتح' : 'التبديل إلى الوضع الداكن';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'حسابي',
              textAlign: TextAlign.center,
              style: AppTypography.title.copyWith(color: c.ink),
            ),
            const SizedBox(height: 24),
            GoldButton.secondary(
              label: label,
              onTap: AppStateScope.read(context).toggleTheme,
            ),
          ],
        ),
      ),
    );
  }
}
