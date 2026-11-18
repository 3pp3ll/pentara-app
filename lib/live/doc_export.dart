/// تحويل الخلاصة (Markdown خفيف) لنسخ واضح وملف Word بجداول حقيقية.
library;

final _rule = RegExp(r'^\s*:?-{2,}:?\s*$');

List<String> _cells(String line) {
  final r = line.trim();
  return r.substring(1, r.endsWith('|') ? r.length - 1 : r.length).split('|').map((x) => x.trim()).toList();
}

String _plain(String s) => s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*|__(.+?)__|`([^`]+)`'), (m) => m[1] ?? m[2] ?? m[3] ?? '');

/// نص النسخ: الجداول تُنسخ أعمدة مفصولة بـ Tab (تلصق كجدول في Excel وGoogle Sheets وWord)،
/// وتُزال رموز التنسيق.
String copyText(String md) {
  final out = <String>[];
  for (final raw in md.replaceAll('\r', '').split('\n')) {
    final line = raw.trim();
    if (line.startsWith('|')) {
      final cells = _cells(line);
      if (cells.every(_rule.hasMatch)) continue;
      out.add(cells.map(_plain).join('\t'));
      continue;
    }
    final h = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(line);
    out.add(_plain(h != null ? h.group(1)! : raw));
  }
  return out.join('\n');
}

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _inlineHtml(String s) => _esc(s)
    .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*|__(.+?)__'), (m) => '<b>${m[1] ?? m[2]}</b>')
    .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => '<code>${m[1]}</code>');

/// ملف Word (HTML يفتحه Word مباشرة) بعناوين ونقاط وجداول بحدود.
String toWordHtml(String title, String md) {
  final b = StringBuffer()
    ..write('<html xmlns:o="urn:schemas-microsoft-com:office:office" '
        'xmlns:w="urn:schemas-microsoft-com:office:word"><head><meta charset="utf-8">'
        '<title>${_esc(title)}</title><style>'
        'body{font-family:Arial,"Segoe UI",sans-serif;direction:rtl;font-size:12pt;line-height:1.6}'
        'h1{color:#8C6A1D;font-size:18pt}h2{color:#8C6A1D;font-size:15pt}h3{font-size:13pt}'
        'table{border-collapse:collapse;width:100%;margin:8pt 0}'
        'th,td{border:1px solid #BFAE7E;padding:5pt 7pt;vertical-align:top;text-align:right}'
        'th{background:#F4ECD8}</style></head><body dir="rtl">')
    ..write('<h1>${_esc(title)}</h1>');
  final lines = md.replaceAll('\r', '').split('\n');
  var i = 0;
  var inList = false;
  void closeList() {
    if (inList) b.write('</ul>');
    inList = false;
  }

  while (i < lines.length) {
    final line = lines[i].trim();
    if (line.startsWith('|')) {
      closeList();
      final rows = <List<String>>[];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        final cells = _cells(lines[i]);
        if (!cells.every(_rule.hasMatch)) rows.add(cells);
        i++;
      }
      b.write('<table>');
      for (var r = 0; r < rows.length; r++) {
        final tag = r == 0 ? 'th' : 'td';
        b.write('<tr>${rows[r].map((x) => '<$tag>${_inlineHtml(x)}</$tag>').join()}</tr>');
      }
      b.write('</table>');
      continue;
    }
    final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    final li = RegExp(r'^(?:[-*•]|\d+[.)])\s+(.*)$').firstMatch(line);
    if (line.isEmpty) {
      closeList();
    } else if (h != null) {
      closeList();
      final lv = h.group(1)!.length.clamp(2, 3);
      b.write('<h$lv>${_inlineHtml(h.group(2)!)}</h$lv>');
    } else if (li != null) {
      if (!inList) b.write('<ul>');
      inList = true;
      b.write('<li>${_inlineHtml(li.group(1)!)}</li>');
    } else if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(line)) {
      closeList();
      b.write('<hr>');
    } else {
      closeList();
      b.write('<p>${_inlineHtml(line.startsWith('>') ? line.substring(1).trim() : line)}</p>');
    }
    i++;
  }
  closeList();
  b.write('<p style="color:#888;font-size:9pt">Pentara AI</p></body></html>');
  return b.toString();
}
