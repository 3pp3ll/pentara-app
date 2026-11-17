import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/gold_button.dart';
import '../widgets/project_card.dart' show latinFigures;
import 'live_api.dart';
import 'live_session.dart';

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
  final _newPass = TextEditingController();
  bool _signupMode = false;
  bool _editing = false;
  bool _showPass = false;

  LiveController get live => LiveController.instance;

  @override
  void dispose() {
    for (final c in [_name, _email, _pass, _code, _newPass]) {
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

  Future<void> _saveEdit() async {
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
    if (!mounted || live.error != null) return;
    _pass.clear();
    _newPass.clear();
    setState(() => _editing = false);
    _toast('حُفظت بياناتك');
  }

  void _startEdit() {
    final u = live.user!;
    _name.text = u.name;
    _email.text = u.email;
    _pass.clear();
    _newPass.clear();
    setState(() => _editing = true);
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
        const SizedBox(height: 12),
        _frame(context, [
          _infoRow(context, 'رقم الحساب', u.id, latin: true, copy: true),
          _infoRow(context, 'البريد', u.email.isEmpty ? '—' : u.email, latin: true),
          const SizedBox(height: 12),
          Text(
            u.hasPlan ? 'تجديد أو ترقية: الصق كوداً جديداً' : 'فعّل باقتك: الصق الكود الذي وصلك من المتجر',
            style: AppTypography.label.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: 8),
          _field(context, _code, 'PNT-XXXX-XXXX-XXXX', latin: true),
          const SizedBox(height: 8),
          GoldButton.primary(label: 'تفعيل الكود', expand: true, onTap: live.busy ? null : _activate),
          const SizedBox(height: 4),
          if (_editing) ...[
            const SizedBox(height: 12),
            Divider(color: c.border, height: 1),
            const SizedBox(height: 12),
            Text('تعديل بياناتك', style: AppTypography.bodyStrong.copyWith(color: c.ink)),
            const SizedBox(height: 8),
            _field(context, _name, 'الاسم'),
            const SizedBox(height: 8),
            _field(context, _email, 'البريد الإلكتروني', latin: true, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 8),
            _field(context, _newPass, 'كلمة مرور جديدة (اختياري)', obscure: true),
            const SizedBox(height: 8),
            _field(context, _pass, 'كلمة المرور الحالية (لتغيير البريد أو كلمة المرور)', obscure: true),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GoldButton.primary(label: 'حفظ', expand: true, onTap: live.busy ? null : _saveEdit),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GoldButton.secondary(
                    label: 'إلغاء',
                    expand: true,
                    onTap: () => setState(() => _editing = false),
                  ),
                ),
              ],
            ),
          ],
          if (live.error != null) ...[
            const SizedBox(height: 8),
            Text(live.error!, style: AppTypography.label.copyWith(color: const Color(0xFFA8322E))),
          ],
          Row(
            children: [
              if (!_editing)
                TextButton(
                  onPressed: _startEdit,
                  child: Text('تعديل البيانات', style: AppTypography.label.copyWith(color: c.goldText)),
                ),
              TextButton(
                onPressed: live.busy ? null : live.refresh,
                child: Text('تحديث الرصيد', style: AppTypography.label.copyWith(color: c.goldText)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await live.signOut();
                  LiveHub.instance.sessions = const [];
                  LiveHub.instance.newSession();
                },
                child: Text('خروج', style: AppTypography.label.copyWith(color: c.inkMuted)),
              ),
            ],
          ),
        ]),
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
      {bool latin = false, bool obscure = false, TextInputType? keyboard}) {
    final c = context.colors;
    final base = latin ? latinFigures(AppTypography.body) : AppTypography.body;
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
        hintStyle: AppTypography.label.copyWith(color: c.inkMuted),
        filled: true,
        fillColor: c.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

  Widget _infoRow(BuildContext context, String label, String value, {bool latin = false, bool copy = false}) {
    final c = context.colors;
    final vStyle = (latin ? latinFigures(AppTypography.bodyStrong) : AppTypography.bodyStrong).copyWith(color: c.ink);
    Widget v = Text(value, style: vStyle, overflow: TextOverflow.ellipsis);
    if (latin) v = Directionality(textDirection: TextDirection.ltr, child: v);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: AppTypography.label.copyWith(color: c.inkMuted)),
          const SizedBox(width: 12),
          Expanded(child: Align(alignment: AlignmentDirectional.centerEnd, child: v)),
          if (copy)
            IconButton(
              tooltip: 'نسخ',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                _toast('نُسخ');
              },
              icon: Icon(Icons.copy_rounded, size: 18, color: c.goldText),
            ),
        ],
      ),
    );
  }
}
