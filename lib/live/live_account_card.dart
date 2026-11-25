import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/glyph.dart';
import '../widgets/gold_button.dart';
import '../widgets/project_card.dart' show latinFigures;
import 'live_api.dart';
import 'live_session.dart';
import '../widgets/center_panel.dart';

/// بطاقة الحساب: قبل الدخول (تسجيل دخول / حساب جديد)، وبعده (الرصيد، الباقة،
/// تفعيل كود المتجر، تعديل البيانات، الخروج).
class LiveAccountCard extends StatefulWidget {
  const LiveAccountCard({super.key});

  @override
  State<LiveAccountCard> createState() => _LiveAccountCardState();
}

class _LiveAccountCardState extends State<LiveAccountCard> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _code = TextEditingController();
  bool _signupMode = false;
  bool _showPass = false;

  LiveController get live => LiveController.instance;

  @override
  void dispose() {
    for (final c in [_name, _email, _pass, _code]) {
      c.dispose();
    }
    super.dispose();
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

  Future<void> _submitAuth() async {
    FocusScope.of(context).unfocus();
    if (_signupMode) {
      await live.signup(_name.text, _email.text, _pass.text);
    } else {
      final moved = await live.signin(_email.text, _pass.text);
      if (moved > 0 && mounted && live.error == null) _toast('رُبطت جلستك التجريبية بحسابك');
    }
    if (!mounted || live.error != null) return;
    _pass.clear();
    _toast(_signupMode ? 'أهلاً ${live.displayName}، تم إنشاء حسابك' : 'أهلاً ${live.displayName}');
    LiveHub.instance.loadList();
  }

  Future<void> _activate() async {
    await live.activate(_code.text);
    if (!mounted) return;
    if (live.error == null) {
      _code.clear();
      _toast('تم تفعيل الباقة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: live,
      builder: (context, _) => live.isRegistered ? _signedIn(context) : _auth(context),
    );
  }

  // ---- قبل الدخول ----------------------------------------------------------

  Widget _auth(BuildContext context) {
    final c = context.colors;
    return _frame(
      context,
      [
        Row(
          children: [
            Expanded(child: _tab(context, 'تسجيل الدخول', !_signupMode, () => setState(() => _signupMode = false))),
            const SizedBox(width: 8),
            Expanded(child: _tab(context, 'حساب جديد', _signupMode, () => setState(() => _signupMode = true))),
          ],
        ),
        const SizedBox(height: 14),
        if (!live.configured)
          Text('لم يُربط السيرفر بعد.', style: AppTypography.label.copyWith(color: c.inkMuted))
        else ...[
          if (live.isGuest)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'جلستك التجريبية ستنتقل لحسابك تلقائياً.',
                style: AppTypography.label.copyWith(color: c.goldText),
              ),
            ),
          if (_signupMode) ...[
            _field(context, _name, 'الاسم'),
            const SizedBox(height: 8),
          ],
          _field(context, _email, 'البريد الإلكتروني', latin: true, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 8),
          _field(context, _pass, 'كلمة المرور (6 أحرف على الأقل)', obscure: true),
          const SizedBox(height: 12),
          GoldButton.primary(
            label: _signupMode ? 'إنشاء الحساب' : 'دخول',
            expand: true,
            onTap: live.busy ? null : _submitAuth,
          ),
          const SizedBox(height: 8),
          Text(
            'الحساب يعمل على جهاز واحد (أول جهاز تسجّل منه). لنقله لجهاز آخر تواصل مع الدعم.',
            style: AppTypography.caption.copyWith(color: c.inkMuted),
          ),
        ],
        if (live.error != null) ...[
          const SizedBox(height: 8),
          Text(live.error!, style: AppTypography.label.copyWith(color: const Color(0xFFA8322E))),
        ],
      ],
    );
  }

  Widget _tab(BuildContext context, String label, bool on, VoidCallback tap) {
    final c = context.colors;
    return Material(
      color: on ? c.surfaceSoft : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: on ? c.goldLine : c.border),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: tap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(label,
                style: AppTypography.label.copyWith(
                  color: on ? c.goldText : c.ink,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                )),
          ),
        ),
      ),
    );
  }

  // ---- بعد الدخول -----------------------------------------------------------

  Widget _signedIn(BuildContext context) {
    final c = context.colors;
    final u = live.user!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _balanceTile(context, u),
        const SizedBox(height: 10),
        // تجديد أو ترقية: بطاقة مضغوطة (الرقم والبريد موجودان فوق).
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.goldLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Glyph(Icons.confirmation_number_rounded, tone: GlyphTone.gold, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      u.hasPlan ? 'تجديد أو ترقية: الصق كود الخصم أو الباقة' : 'فعّل باقتك: الصق الكود الذي وصلك',
                      style: AppTypography.caption.copyWith(color: c.inkMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _field(context, _code, 'PNT-XXXX-XXXX-XXXX', latin: true, compact: true)),
                  const SizedBox(width: 8),
                  GoldButton.primary(label: 'تفعيل', onTap: live.busy ? null : _activate),
                ],
              ),
              if (live.error != null) ...[
                const SizedBox(height: 6),
                Text(live.error!, style: AppTypography.caption.copyWith(color: const Color(0xFFA8322E))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// رصيد النماذج: بطاقة ذهبية لافتة.
  Widget _balanceTile(BuildContext context, LiveUser u) {
    const ink = Color(0xFF14182B);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFFE6CF94), Color(0xFFC9A75A), Color(0xFFA8832F)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x33A8832F), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x47FFFFFF),
              border: Border.all(color: const Color(0x99FFFFFF)),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: ink, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('رصيد النماذج', style: AppTypography.label.copyWith(color: ink)),
                const SizedBox(height: 2),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    u.balanceLabel,
                    style: latinFigures(AppTypography.metric).copyWith(color: ink, fontSize: 30),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              u.hasPlan ? u.planName : 'بدون باقة',
              style: AppTypography.caption.copyWith(color: const Color(0xFFE6CF94)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _frame(BuildContext context, List<Widget> children) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.goldLine, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _field(BuildContext context, TextEditingController ctrl, String hint,
      {bool latin = false, bool obscure = false, TextInputType? keyboard, bool compact = false}) {
    final c = context.colors;
    final base = (latin ? latinFigures(AppTypography.body) : AppTypography.body)
        .copyWith(fontSize: compact ? 13 : null);
    return TextField(
      controller: ctrl,
      obscureText: obscure && !_showPass,
      keyboardType: keyboard,
      textDirection: latin ? TextDirection.ltr : null,
      autocorrect: false,
      enableSuggestions: !obscure,
      style: base.copyWith(color: c.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.label.copyWith(color: c.inkMuted, fontSize: compact ? 12 : null),
        filled: true,
        fillColor: c.bg,
        isDense: compact,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 10 : 12),
        suffixIcon: obscure
            ? IconButton(
                tooltip: _showPass ? 'إخفاء' : 'إظهار',
                onPressed: () => setState(() => _showPass = !_showPass),
                icon: Icon(_showPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 20, color: c.inkMuted),
              )
            : null,
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
}

/// صف إعداد بأيقونة الهوية (تعديل البيانات، تسجيل الخروج…).
class LiveSettingRow extends StatelessWidget {
  const LiveSettingRow({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    this.sub,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final GlyphTone tone;
  final String title;
  final String? sub;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.border)),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Glyph(icon, tone: tone, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.bodyStrong
                            .copyWith(color: danger ? const Color(0xFFA8322E) : c.ink, fontSize: 15)),
                    if (sub != null) Text(sub!, style: AppTypography.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: c.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// «تعديل البيانات» و«تسجيل الخروج» أسفل شاشة حسابي (للمسجّلين فقط).
class LiveAccountActions extends StatelessWidget {
  const LiveAccountActions({super.key, this.logoutOnly = false});

  final bool logoutOnly;

  @override
  Widget build(BuildContext context) {
    final live = LiveController.instance;
    return ListenableBuilder(
      listenable: live,
      builder: (context, _) {
        if (!live.isRegistered) return const SizedBox.shrink();
        final u = live.user!;
        if (logoutOnly) {
          return LiveSettingRow(
            icon: Icons.logout_rounded,
            tone: GlyphTone.slate,
            title: 'تسجيل خروج',
            danger: true,
            onTap: () async {
              await live.signOut();
              LiveHub.instance.sessions = const [];
              LiveHub.instance.newSession();
            },
          );
        }
        return LiveSettingRow(
          icon: Icons.manage_accounts_rounded,
          tone: GlyphTone.blue,
          title: 'تعديل البيانات',
          sub: u.pendingEmail.isNotEmpty ? 'البريد الجديد بانتظار موافقة الإدارة' : 'الاسم والبريد وكلمة المرور',
          onTap: () => showCenterPanel<void>(context, (_) => const _EditSheet()),
        );
      },
    );
  }
}

class _EditSheet extends StatefulWidget {
  const _EditSheet();

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final live = LiveController.instance;
  late final _name = TextEditingController(text: live.user?.name ?? '');
  late final _email = TextEditingController(text: live.user?.email ?? '');
  final _pass = TextEditingController();
  final _newPass = TextEditingController();
  bool _show = false;
  String? _msg;

  @override
  void dispose() {
    for (final c in [_name, _email, _pass, _newPass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final u = live.user;
    if (u == null) return;
    FocusScope.of(context).unfocus();
    final emailChanged = _email.text.trim().toLowerCase() != u.email;
    await live.updateAccount(
      name: _name.text.trim(),
      email: emailChanged ? _email.text.trim() : null,
      password: (emailChanged || _newPass.text.isNotEmpty) ? _pass.text : null,
      newPassword: _newPass.text,
    );
    if (!mounted) return;
    if (live.error != null) {
      setState(() => _msg = live.error);
      return;
    }
    final pending = live.user?.pendingEmail.isNotEmpty ?? false;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(pending && emailChanged
          ? 'حُفظت بياناتك. البريد الجديد يتفعّل بعد موافقة الإدارة، وتقدر تستخدم التطبيق عادي.'
          : 'حُفظت بياناتك'),
    ));
  }

  Widget _f(TextEditingController c, String hint, {bool latin = false, bool obscure = false}) {
    final col = context.colors;
    return TextField(
      controller: c,
      obscureText: obscure && !_show,
      textDirection: latin ? TextDirection.ltr : null,
      autocorrect: false,
      style: (latin ? latinFigures(AppTypography.body) : AppTypography.body).copyWith(color: col.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.label.copyWith(color: col.inkMuted),
        filled: true,
        fillColor: col.bg,
        suffixIcon: obscure
            ? IconButton(
                onPressed: () => setState(() => _show = !_show),
                icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 20, color: col.inkMuted),
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: col.border)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: col.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: col.goldLine, width: 1.5)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pending = live.user?.pendingEmail ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Glyph(Icons.manage_accounts_rounded, tone: GlyphTone.blue, size: 40),
                const SizedBox(width: 10),
                Text('تعديل البيانات', style: AppTypography.title.copyWith(color: c.ink)),
              ],
            ),
            const SizedBox(height: 14),
            _f(_name, 'الاسم'),
            const SizedBox(height: 8),
            _f(_email, 'البريد الإلكتروني', latin: true),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                pending.isNotEmpty
                    ? 'طلبك لتغيير البريد إلى $pending بانتظار موافقة الإدارة.'
                    : 'تغيير البريد يحتاج موافقة الإدارة، وتكمل استخدام التطبيق عادي. الاسم وكلمة المرور يتغيرون فوراً.',
                style: AppTypography.caption.copyWith(color: c.inkMuted),
              ),
            ),
            _f(_newPass, 'كلمة مرور جديدة (اختياري)', obscure: true),
            const SizedBox(height: 8),
            _f(_pass, 'كلمة المرور الحالية (لتغيير البريد أو كلمة المرور)', obscure: true),
            if (_msg != null) ...[
              const SizedBox(height: 8),
              Text(_msg!, style: AppTypography.label.copyWith(color: const Color(0xFFA8322E))),
            ],
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: live,
              builder: (context, _) =>
                  GoldButton.primary(label: 'حفظ', expand: true, onTap: live.busy ? null : _save),
            ),
          ],
        ),
      ),
    );
  }
}
