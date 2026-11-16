import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_state.dart';
import 'live/live_api.dart';
import 'live/live_table_screen.dart';
import 'screens/account_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lab_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/table_screen.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/app_typography.dart';
import 'widgets/bottom_nav.dart';

/// جذر تطبيق بنتارا.
///
/// ينشئ [AppState] مرة واحدة ويتخلّص منه. خطوة المحاكاة 1200ms تُمرَّر هنا،
/// والمؤقّت الوحيد يعيش في [AppState] ويُلغى في dispose الخاص به. يستمع
/// الجذر لتغيّر المظهر وحده قبل setState، فلا تعيد نبضات المحاكاة بناء
/// MaterialApp. وتُحقن الحالة داخل builder فتراها كل المسارات.
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
    _app = AppState(stepDuration: const Duration(milliseconds: 1200));
    _mode = _app.themeMode;
    _app.addListener(_onAppChanged);
    LiveController.instance.init();
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
const int _labTabIndex = 3;
const int _accountTabIndex = 4;
const int _tabCount = 5;

/// غلاف التنقل: يملك فهرس التبويب ويراقب دورة حياة التطبيق، ويبلّغ
/// [AppState] بظهور الطاولة فقط (ظهور التبويب والتطبيق في المقدمة شرطان).
/// وهو وحده يختار المشروع ويبدّل التبويب ويعرض التنبيهات على سقالته
/// الواحدة، فيظهر التنبيه فوق الشريط السفلي.
/// كل تبويب يُلفّ بـ TickerMode فلا يستمر نبض الأقراص في تبويب مخفي.
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

  /// «مشروع جديد»: يفتح الطاولة الحقيقية (السيرفر). العرض التجريبي يبقى في تبويب الطاولة.
  void _newProject() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LiveTableScreen()),
    );
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
      _tableTabIndex => const TableScreen(),
      _projectsTabIndex => ProjectsScreen(onOpenProject: _openProject),
      _labTabIndex => const LabScreen(),
      _ => const AccountScreen(),
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
              for (var i = 0; i < _tabCount; i++)
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
