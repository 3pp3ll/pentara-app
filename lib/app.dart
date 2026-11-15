import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'theme/app_typography.dart';

/// جذر تطبيق بنتارا.
///
/// TODO(batch-2): تُستبدل الحالة المؤقتة (_mode و_index) بـ AppState
/// الحقيقي في lib/data/app_state.dart عبر InheritedNotifier، وتُحذف
/// _Shell و_TempBottomBar و_PlaceholderScreen و_TempThemeToggle من هذا الملف.
class PentaraApp extends StatefulWidget {
  const PentaraApp({super.key});

  @override
  State<PentaraApp> createState() => _PentaraAppState();
}

class _PentaraAppState extends State<PentaraApp> {
  ThemeMode _mode = ThemeMode.light;
  int _index = 0;

  void _toggleMode() {
    setState(() {
      _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
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
      home: _Shell(
        index: _index,
        onSelect: _select,
        onToggleMode: _toggleMode,
      ),
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

const int _accountTabIndex = 4;

// TODO(batch-2): يُستبدل بالهيكل الحقيقي مع bottom_nav.dart والشاشات.
class _Shell extends StatelessWidget {
  const _Shell({
    required this.index,
    required this.onSelect,
    required this.onToggleMode,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleMode;

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
            index: index,
            children: [
              for (var i = 0; i < _tabLabels.length; i++)
                _PlaceholderScreen(
                  title: _tabLabels[i],
                  trailing: i == _accountTabIndex
                      ? _TempThemeToggle(onTap: onToggleMode)
                      : null,
                ),
            ],
          ),
        ),
        bottomNavigationBar: _TempBottomBar(
          index: index,
          onSelect: onSelect,
        ),
      ),
    );
  }
}

// TODO(batch-2): تُستبدل بشاشات lib/screens/.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

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
            if (trailing != null) ...[
              const SizedBox(height: 24),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// زر مؤقت لتبديل المظهر. يستخدم InkWell ونصاً بلون ink،
/// لا TextButton، حتى لا يرث لون ColorScheme.primary.
// TODO(batch-2): يُستبدل بزر المظهر الحقيقي في account_screen.dart.
class _TempThemeToggle extends StatelessWidget {
  const _TempThemeToggle({required this.onTap});

  final VoidCallback onTap;

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
        onTap: onTap,
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
// TODO(batch-2): يُستبدل بـ lib/widgets/bottom_nav.dart برموز CustomPainter.
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
