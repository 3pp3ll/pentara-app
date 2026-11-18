import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// ملف PDF عربي (من اليمين) للخلاصة: عناوين ونقاط وجداول بحدود.
Future<Uint8List> buildSummaryPdf(String title, String md) async {
  final reg = pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/IBMPlexSansArabic-SemiBold.ttf'));
  const gold = PdfColor.fromInt(0xFF8C6A1D);
  const line = PdfColor.fromInt(0xFFBFAE7E);
  const headBg = PdfColor.fromInt(0xFFF4ECD8);
  final base = pw.TextStyle(font: reg, fontBold: bold, fontSize: 11, lineSpacing: 3);
  final strong = base.copyWith(font: bold);

  String plain(String s) =>
      s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*|__(.+?)__|`([^`]+)`'), (m) => m[1] ?? m[2] ?? m[3] ?? '');
  List<String> cells(String l) {
    final r = l.trim();
    return r.substring(1, r.endsWith('|') ? r.length - 1 : r.length).split('|').map((x) => plain(x.trim())).toList();
  }

  final rule = RegExp(r'^\s*:?-{2,}:?\s*$');
  final blocks = <pw.Widget>[
    pw.Text(title, style: strong.copyWith(fontSize: 20, color: gold)),
    pw.SizedBox(height: 10),
  ];
  final lines = md.replaceAll('\r', '').split('\n');
  var i = 0;
  while (i < lines.length) {
    final l = lines[i].trim();
    if (l.startsWith('|')) {
      final rows = <List<String>>[];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        final c = cells(lines[i]);
        if (!c.every(rule.hasMatch)) rows.add(c);
        i++;
      }
      if (rows.isEmpty) continue;
      final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
      // جدول pdf يرتب الأعمدة من اليسار، فنعكسها حتى يكون العمود الأول يميناً.
      List<String> rtl(List<String> r) => [for (var k = cols - 1; k >= 0; k--) k < r.length ? r[k] : ''];
      final widths = <int, pw.TableColumnWidth>{};
      for (var k = 0; k < cols; k++) {
        var sum = 0;
        for (final r in rows.skip(1)) {
          if (k < r.length) sum += r[k].length;
        }
        final avg = rows.length > 1 ? sum / (rows.length - 1) : 4.0;
        widths[cols - 1 - k] = pw.FlexColumnWidth(avg.clamp(4, 60).toDouble());
      }
      blocks.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.TableHelper.fromTextArray(
          headers: rtl(rows.first),
          data: [for (final r in rows.skip(1)) rtl(r)],
          headerStyle: strong.copyWith(fontSize: 10),
          cellStyle: base.copyWith(fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: headBg),
          cellAlignment: pw.Alignment.topRight,
          headerAlignment: pw.Alignment.centerRight,
          headerDirection: pw.TextDirection.rtl,
          tableDirection: pw.TextDirection.rtl,
          border: pw.TableBorder.all(color: line, width: 0.6),
          columnWidths: widths,
        ),
      ));
      continue;
    }
    final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(l);
    final li = RegExp(r'^(?:[-*•]|\d+[.)])\s+(.*)$').firstMatch(l);
    if (l.isEmpty || RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(l)) {
      blocks.add(pw.SizedBox(height: 4));
    } else if (h != null) {
      blocks.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
        child: pw.Text(plain(h.group(2)!),
            style: strong.copyWith(fontSize: h.group(1)!.length <= 2 ? 15 : 13, color: h.group(1)!.length <= 2 ? gold : null)),
      ));
    } else if (li != null) {
      blocks.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Text('•  ${plain(li.group(1)!)}', style: base),
      ));
    } else {
      blocks.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(plain(l.startsWith('>') ? l.substring(1).trim() : l), style: base),
      ));
    }
    i++;
  }

  final doc = pw.Document(title: title, theme: pw.ThemeData.withFont(base: reg, bold: bold));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    textDirection: pw.TextDirection.rtl,
    margin: const pw.EdgeInsets.all(36),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerLeft,
      child: pw.Text('Pentara AI · ${ctx.pageNumber}/${ctx.pagesCount}', style: base.copyWith(fontSize: 8, color: PdfColors.grey600)),
    ),
    build: (_) => blocks,
  ));
  return doc.save();
}
