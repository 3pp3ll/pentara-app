import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/gold_button.dart';
import '../widgets/project_card.dart' show latinFigures;
import 'live_api.dart';

/// بطاقة الحساب الحقيقي: إنشاء حساب، الدخول برمز، تفعيل كود المتجر، والرصيد.
class LiveAccountCard extends StatefulWidget {
  const LiveAccountCard({super.key});

  @override
  State<LiveAccountCard> createState() => _LiveAccountCardState();
}

class _LiveAccountCardState extends State<LiveAccountCard> {
  final _code = TextEditingController();
  final _login = TextEditingController();
  bool _showLogin = false;

  LiveController get live => LiveController.instance;

  @override
  void dispose() {
    _code.dispose();
    _login.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    await live.activate(_code.text);
    if (!mounted) return;
    if (live.error == null) {
      _code.clear();
      _toast('تم تفعيل الباقة');
    }
  }

  Future<void> _useLogin() async {
    await live.useLogin(_login.text);
    if (!mounted) return;
    if (live.error == null) {
      _login.clear();
      setState(() => _showLogin = false);
      _toast('تم الدخول');
    }
  }

  void _toast(String m) {
    final c = context.colors;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        content: Text(m, style: AppTypography.label.copyWith(color: c.bg)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: live,
      builder: (context, _) => _card(context),
    );
  }

  Widget _card(BuildContext context) {
    final c = context.colors;
    final u = live.user;

    final children = <Widget>[
      Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: u != null ? const Color(0xFF1F6B4A) : c.inkMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              u != null ? 'حسابك الحقيقي متصل' : 'الحساب الحقيقي',
              style: AppTypography.bodyStrong.copyWith(color: c.ink),
            ),
          ),
          if (live.busy)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.goldLine),
            ),
        ],
      ),
      const SizedBox(height: 8),
    ];

    if (!live.configured) {
      children.add(Text(
        'لم يُربط السيرفر بعد. بعد ربطه يظهر هنا إنشاء الحساب وتفعيل الباقة.',
        style: AppTypography.label.copyWith(color: c.inkMuted),
      ));
    } else if (u == null) {
      children.addAll([
        Text(
          'أنشئ حسابك ليصلك رقم ID خاص، ثم فعّل باقتك بالكود الذي يصلك من المتجر.',
          style: AppTypography.label.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: 12),
        GoldButton.primary(
          label: 'إنشاء حساب جديد',
          expand: true,
          onTap: live.busy ? null : live.register,
        ),
        const SizedBox(height: 8),
        GoldButton.secondary(
          label: _showLogin ? 'إخفاء' : 'لدي رمز دخول',
          expand: true,
          onTap: () => setState(() => _showLogin = !_showLogin),
        ),
        if (_showLogin) ...[
          const SizedBox(height: 8),
          _field(context, _login, 'الصق رمز الدخول هنا', latin: true),
          const SizedBox(height: 8),
          GoldButton.primary(
            label: 'دخول',
            expand: true,
            onTap: live.busy ? null : _useLogin,
          ),
        ],
      ]);
    } else {
      children.addAll([
        _infoRow(context, 'رقم الحساب', u.id, latin: true, copy: true),
        _infoRow(context, 'الباقة', u.hasPlan ? u.planName : 'غير مفعّلة'),
        _infoRow(context, 'الرصيد', u.balanceLabel, latin: true),
        const SizedBox(height: 12),
        Text(
          u.hasPlan ? 'تجديد أو ترقية: الصق كوداً جديداً' : 'فعّل باقتك: الصق الكود الذي وصلك من المتجر',
          style: AppTypography.label.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: 8),
        _field(context, _code, 'PNT-XXXX-XXXX-XXXX', latin: true),
        const SizedBox(height: 8),
        GoldButton.primary(
          label: 'تفعيل الكود',
          expand: true,
          onTap: live.busy ? null : _activate,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: live.busy ? null : live.refresh,
              child: Text('تحديث الرصيد', style: AppTypography.label.copyWith(color: c.goldText)),
            ),
            const Spacer(),
            TextButton(
              onPressed: live.signOut,
              child: Text('خروج', style: AppTypography.label.copyWith(color: c.inkMuted)),
            ),
          ],
        ),
      ]);
    }

    if (live.error != null) {
      children.addAll([
        const SizedBox(height: 8),
        Text(
          live.error!,
          style: AppTypography.label.copyWith(color: const Color(0xFFA8322E)),
        ),
      ]);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.goldLine, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _field(BuildContext context, TextEditingController ctrl, String hint, {bool latin = false}) {
    final c = context.colors;
    final base = latin ? latinFigures(AppTypography.body) : AppTypography.body;
    return TextField(
      controller: ctrl,
      textDirection: latin ? TextDirection.ltr : null,
      autocorrect: false,
      style: base.copyWith(color: c.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: base.copyWith(color: c.inkMuted),
        filled: true,
        fillColor: c.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.goldLine, width: 1.5),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value,
      {bool latin = false, bool copy = false}) {
    final c = context.colors;
    final vStyle = (latin ? latinFigures(AppTypography.bodyStrong) : AppTypography.bodyStrong)
        .copyWith(color: c.ink);
    Widget v = Text(value, style: vStyle);
    if (latin) v = Directionality(textDirection: TextDirection.ltr, child: v);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: AppTypography.label.copyWith(color: c.inkMuted)),
          const Spacer(),
          v,
          if (copy)
            IconButton(
              tooltip: 'نسخ',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                _toast('نُسخ رقم الحساب');
              },
              icon: Icon(Icons.copy_rounded, size: 18, color: c.goldText),
            ),
        ],
      ),
    );
  }
}
