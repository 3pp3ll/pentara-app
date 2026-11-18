import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_state.dart';
import 'live/app_update.dart';
import 'live/live_api.dart';
import 'live/live_lab_screen.dart';
import 'live/live_projects_screen.dart';
import 'live/live_session.dart';
import 'live/live_table_screen.dart';
import 'screens/account_screen.dart';
import 'screens/home_screen.dart';
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
    AppUpdate.instance.check();
    LiveController.instance.init().then((_) {
      if (LiveController.instance.isSignedIn) LiveHub.instance.loadList();
    });
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
    final visible = _index == _tableTabIndex && _resumed;
    _app?.setTableVisible(visible);
    // بعد الخروج من الطاولة أو من التطبيق تُطوى الجلسة وتظهر قائمة الجلسات.
    if (!visible) LiveHub.instance.collapse();
  }

  /// سجل التبويبات: زر الرجوع في الجوال يعود للتبويب السابق، ثم للرئيسية، ثم يخرج.
  final List<int> _history = [];

  void _select(int i, {bool remember = true}) {
    if (i == _index) return;
    if (remember) {
      _history.remove(_index);
      _history.add(_index);
      if (_history.length > 10) _history.removeAt(0);
    }
    setState(() => _index = i);
    _syncTableVisibility();
  }

  /// شاشة عريضة (الموقع على الكمبيوتر).
  bool _wide(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;

  Widget _content() => Column(
        children: [
          const UpdateBanner(),
          Expanded(
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
        ],
      );

  void _back() {
    while (_history.isNotEmpty) {
      final prev = _history.removeLast();
      if (prev != _index) {
        _select(prev, remember: false);
        return;
      }
    }
    if (_index != _homeTabIndex) _select(_homeTabIndex, remember: false);
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

  /// «مشروع جديد»: جلسة جديدة في تبويب الطاولة الحقيقية.
  void _newProject() {
    if (!LiveHub.instance.current.running) LiveHub.instance.newSession();
    _select(_tableTabIndex);
  }

  /// الضغط على جلسة محفوظة: تُفتح في الطاولة.
  Future<void> _openProject(String id) async {
    final ok = await LiveHub.instance.open(id);
    if (!mounted) return;
    if (ok) {
      LiveHub.instance.expand();
      _select(_tableTabIndex);
    } else {
      _notify('تعذّر فتح الجلسة. تحقق من الاتصال');
    }
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
      _tableTabIndex => const LiveTableScreen(embedded: true),
      _projectsTabIndex => LiveProjectsScreen(
          onOpened: () => _select(_tableTabIndex),
          onNew: _newProject,
        ),
      _labTabIndex => LiveLabScreen(onOpen: _openProject),
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
      child: PopScope(
        canPop: _index == _homeTabIndex && _history.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          bottom: false,
          child: _wide(context)
              // الكمبيوتر: شريط جانبي، والمحتوى في عمود مريح للقراءة وسط الصفحة.
              ? Row(
                  children: [
                    SideNav(currentIndex: _index, onTap: _select),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: _content(),
                        ),
                      ),
                    ),
                  ],
                )
              : _content(),
        ),
        // SafeArea السفلية داخل BottomNav مرة واحدة.
        bottomNavigationBar: _wide(context)
            ? null
            : BottomNav(
                currentIndex: _index,
                onTap: _select,
              ),
      ),
      ),
    );
  }
}
