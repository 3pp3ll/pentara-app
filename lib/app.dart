import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_state.dart';
import 'data/mock_data.dart';
import 'data/models.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/app_typography.dart';

/// جذر تطبيق بنتارا.
///
/// ينشئ [AppState] مرة واحدة ويتخلّص منه. يستمع لتغيّر المظهر وحده قبل
/// setState، فلا تعيد نبضات المحاكاة بناء MaterialApp. وتُحقن الحالة داخل
/// builder فتراها كل المسارات.
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

/// أسماء التبويبات بالترتيب من اليمين (الفهرس 0 = الرئيسية).
/// RTL يضع العنصر الأول في أقصى اليمين تلقائياً، بلا عكس يدوي.
const List<String> _tabLabels = [
  'الرئيسية',
  'الطاولة',
  'المشاريع',
  'المختبر',
  'حسابي',
];

const int _tableTabIndex = 1;
const int _accountTabIndex = 4;

/// غلاف التنقل: يملك فهرس التبويب ويراقب دورة حياة التطبيق، ويبلّغ
/// [AppState] بظهور الطاولة فقط: ظهور التبويب والتطبيق في المقدمة شرطان.
// TODO(batch-3): يُستبدل بالهيكل الحقيقي مع bottom_nav.dart والشاشات.
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
              for (var i = 0; i < _tabLabels.length; i++)
                _PlaceholderScreen(
                  title: _tabLabels[i],
                  extra: switch (i) {
                    _tableTabIndex => const _TempTableStatus(),
                    _accountTabIndex => const _TempThemeToggle(),
                    _ => null,
                  },
                ),
            ],
          ),
        ),
        bottomNavigationBar: _TempBottomBar(
          index: _index,
          onSelect: _select,
        ),
      ),
    );
  }
}

// TODO(batch-3): تُستبدل بشاشات lib/screens/.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, this.extra});

  final String title;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title.copyWith(color: c.ink),
            ),
            if (extra != null) ...[
              const SizedBox(height: 24),
              extra!,
            ],
          ],
        ),
      ),
    );
  }
}

/// عرض مؤقت لحالة المحاكاة للتحقق من الطبقة. يعتمد على AppState
/// وحده من بين العناصر المؤقتة، فيُعاد بناؤه مع كل نبضة دون غيره.
// TODO(batch-3): يُحذف مع بناء table_screen.dart.
class _TempTableStatus extends StatelessWidget {
  const _TempTableStatus();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final app = AppStateScope.of(context);
    final project = app.activeProject;
    final speakerId = app.centerMemberId;
    final speaker =
        speakerId == null ? 'لا يوجد' : MockData.memberOf(speakerId).title;

    final lines = <String>[
      project?.name ?? '',
      'المتحدث: $speaker',
      toArabicDigits(
        'الجولة ${app.currentRound} — الرسائل ${app.cursor} من ${app.messageCount}',
      ),
      app.summaryVisible
          ? 'الخلاصة ظاهرة'
          : (app.isRunning ? 'المحاكاة تعمل' : 'المحاكاة متوقفة'),
    ];

    return Container(
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
          for (final line in lines)
            Text(
              line,
              textAlign: TextAlign.center,
              style: AppTypography.label.copyWith(color: c.inkMuted),
            ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _TempAction(label: 'إعادة', onTap: app.restartSimulation),
              _TempAction(label: 'الخلاصة', onTap: app.jumpToSummary),
              _TempAction(label: 'حفظ', onTap: app.saveSummary),
            ],
          ),
        ],
      ),
    );
  }
}

class _TempAction extends StatelessWidget {
  const _TempAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: StadiumBorder(side: BorderSide(color: c.border)),
          ),
          child: Text(
            label,
            style: AppTypography.label.copyWith(color: c.ink),
          ),
        ),
      ),
    );
  }
}

/// زر مؤقت لتبديل المظهر. InkWell ونص بلون ink، لا TextButton،
/// حتى لا يرث لون ColorScheme.primary.
// TODO(batch-3): يُستبدل بزر المظهر الحقيقي في account_screen.dart.
class _TempThemeToggle extends StatelessWidget {
  const _TempThemeToggle();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = c.brightness == Brightness.dark;
    final label =
        isDark ? 'التبديل إلى الوضع الفاتح' : 'التبديل إلى الوضع الداكن';

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: AppStateScope.read(context).toggleTheme,
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: ShapeDecoration(
            color: c.surface,
            shape: StadiumBorder(side: BorderSide(color: c.goldLine)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.label.copyWith(color: c.ink),
          ),
        ),
      ),
    );
  }
}

/// شريط تنقل سفلي مؤقت: نص ونقطة ذهبية تحت التبويب النشط.
/// surface وحد علوي border، بلا ظل.
// TODO(batch-3): يُستبدل بـ lib/widgets/bottom_nav.dart برموز CustomPainter.
class _TempBottomBar extends StatelessWidget {
  const _TempBottomBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _tabLabels.length; i++)
                Expanded(
                  child: _TempNavItem(
                    label: _tabLabels[i],
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TempNavItem extends StatelessWidget {
  const _TempNavItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const duration = Duration(milliseconds: 300);
    const curve = Curves.easeOutCubic;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: duration,
                curve: curve,
                style: AppTypography.label.copyWith(
                  color: selected ? c.goldText : c.inkMuted,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: duration,
                curve: curve,
                width: selected ? 6 : 0,
                height: 6,
                decoration: BoxDecoration(
                  // gold500 تعبئة لا نص، فيصح استخدامه هنا.
                  color: AppColors.gold500,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
