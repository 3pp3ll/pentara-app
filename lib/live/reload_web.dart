import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// يمسح نسخة التطبيق المخزّنة في المتصفح (Service Worker والكاش) ثم يعيد التحميل
/// برابط جديد، حتى لا يفتح المتصفح النسخة القديمة من جديد.
Future<void> _clearCache() async {
  try {
    final regs = (await web.window.navigator.serviceWorker.getRegistrations().toDart).toDart;
    for (final r in regs) {
      await r.unregister().toDart;
    }
  } catch (_) {}
  try {
    final keys = (await web.window.caches.keys().toDart).toDart;
    for (final k in keys) {
      await web.window.caches.delete(k.toDart).toDart;
    }
  } catch (_) {}
}

void reloadPage() {
  _clearCache().whenComplete(() {
    final loc = web.window.location;
    loc.replace('${loc.origin}${loc.pathname}?v=${DateTime.now().millisecondsSinceEpoch}${loc.hash}');
  });
}
