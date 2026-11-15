import '../theme/app_colors.dart';

// ---------------------------------------------------------------------------
// أدوات الأرقام والتنسيق (دوال نقية بلا ودجتات)
// ---------------------------------------------------------------------------

/// يحوّل الأرقام الغربية إلى العربية (٠–٩). للتواريخ والسرد فقط،
/// لا للأسعار ولا للمؤشرات (تبقى غربية داخل Directionality LTR).
String toArabicDigits(String input) {
  const western = '0123456789';
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final i = western.indexOf(ch);
    buffer.write(i < 0 ? ch : eastern[i]);
  }
  return buffer.toString();
}

/// سنتات الدولار بأعداد صحيحة، بلا فاصلة عائمة.
/// 1000 → $10، و740 → $7.40، و42 → $0.42.
String formatUsd(int cents) {
  assert(cents >= 0);
  final whole = cents ~/ 100;
  final rest = cents % 100;
  if (rest == 0) return '\$$whole';
  return '\$$whole.${rest.toString().padLeft(2, '0')}';
}

/// هللات الريال بمنزلتين دائماً: 1860 → 18.60 ر.س.
String formatSar(int halalas) {
  assert(halalas >= 0);
  final whole = halalas ~/ 100;
  final rest = halalas % 100;
  return '$whole.${rest.toString().padLeft(2, '0')} ر.س';
}

// ---------------------------------------------------------------------------
// الأعضاء
// ---------------------------------------------------------------------------

/// رمز العضو الدلالي. يُرسم لاحقاً بـ CustomPainter (لا إيموجي ولا IconData).
enum MemberSymbol {
  crown,
  starburst8,
  linkedRings,
  star4,
  crosshair,
  doubleDiamond,
}

/// عضو الطاولة. الألوان تُقرأ من MemberPalette القائم ولا تُنسخ.
class Member {
  const Member({
    required this.id,
    required this.title,
    required this.role,
    required this.symbol,
  });

  final MemberId id;

  /// اللقب: الاسم الوحيد الذي يظهر في الواجهة.
  final String title;
  final String role;
  final MemberSymbol symbol;

  MemberPalette get palette => id.palette;
}

// ---------------------------------------------------------------------------
// المشاريع
// ---------------------------------------------------------------------------

/// حالة المشروع. الخمس الأولى هي حالات البطاقات في المرجع.
/// «مرفوض» هي السادسة (تأويل لطلب الدفعة): بلا بطاقة ولا رقاقة تصفية.
enum ProjectStatus {
  verified('متحقق', StatusTone.ok),
  testing('قيد الاختبار', StatusTone.info),
  needsFix('يحتاج تصحيحاً', StatusTone.danger),
  discussing('قيد النقاش', StatusTone.warn),
  idea('فكرة', StatusTone.neutral),
  rejected('مرفوض', StatusTone.danger);

  const ProjectStatus(this.label, this.tone);

  final String label;
  final StatusTone tone;
}

/// مرحلة الجاهزية. منفصلة عن حالة المشروع: «متحقق» ليست «موثَّق» تلقائياً.
enum ReadinessStage {
  generated('مُولَّد', StatusTone.neutral),
  reviewed('مُراجَع', StatusTone.info),
  tested('مُختبَر', StatusTone.warn),
  documented('موثَّق', StatusTone.ok);

  const ReadinessStage(this.label, this.tone);

  final String label;
  final StatusTone tone;
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.readiness,
    required this.costCents,
    required this.mark,
  });

  final String id;
  final String name;
  final String description;
  final ProjectStatus status;

  /// تُحدَّد صراحة لكل مشروع؛ لا دالة تشتقها من الحالة.
  final ReadinessStage readiness;

  /// رقم عرض مستقل (سنتات). لا يُجمع ولا يرتبط برصيد الحساب.
  final int costCents;

  /// حرف داخل قرص الأيقونة (يُرسم لاحقاً). لا إيموجي.
  final String mark;

  String get costLabel => formatUsd(costCents);
}

// ---------------------------------------------------------------------------
// النقاش: الرسائل والجولات والخلاصة
// ---------------------------------------------------------------------------

/// حكم الرسالة: شارة «سليم» أو «مرفوض» مع السبب.
enum MessageVerdict {
  valid('سليم', StatusTone.ok),
  rejected('مرفوض', StatusTone.danger);

  const MessageVerdict(this.label, this.tone);

  final String label;
  final StatusTone tone;
}

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.roundNumber,
    required this.text,
    this.verdict,
    this.reason,
  }) : assert(
          verdict != MessageVerdict.rejected ||
              (reason != null && reason != ''),
          'الرفض يحتاج سبباً',
        );

  final String id;
  final MemberId senderId;
  final int roundNumber;
  final String text;

  /// null لرسائل التوجيه (ملاحظة رئيس الجلسة).
  final MessageVerdict? verdict;
  final String? reason;

  bool get isChairNote => senderId == MemberId.chair;
}

/// جولة مشتقة من الرسائل: [start, end) فهارس في قائمة الرسائل.
class Round {
  const Round({
    required this.number,
    required this.title,
    required this.start,
    required this.end,
  });

  final int number;
  final String title;
  final int start;
  final int end;

  int get length => end - start;
}

enum RoundPhase { done, active, pending }

/// الخلاصة: حقل على النقاش لا فقاعة. مؤلفها رئيس الجلسة.
class Summary {
  const Summary({
    required this.projectId,
    required this.title,
    required this.points,
    required this.readiness,
    required this.authorId,
  });

  final String projectId;
  final String title;
  final List<String> points;
  final ReadinessStage readiness;
  final MemberId authorId;

  /// نص للنسخ. النسخ نفسه (Clipboard) مسؤولية الودجت.
  String toPlainText() =>
      [title, ...points.map((p) => '• $p')].join('\n');
}

/// سيناريو نقاش لمشروع واحد. الجولات مشتقة من الرسائل.
class Discussion {
  Discussion({
    required this.projectId,
    required this.messages,
    required List<String> roundTitles,
    required this.summary,
  }) : rounds = _buildRounds(messages, roundTitles);

  final String projectId;
  final List<Message> messages;
  final List<Round> rounds;
  final Summary summary;

  /// المؤشر الافتراضي عند الفتح: نهاية الجولة ١ بلا كشف أي رسالة من ٢.
  int get initialCursor => rounds.isEmpty ? 0 : rounds.first.end;

  static List<Round> _buildRounds(List<Message> messages, List<String> titles) {
    final result = <Round>[];
    for (var i = 0; i < titles.length; i++) {
      final number = i + 1;
      final first = messages.indexWhere((m) => m.roundNumber == number);
      if (first < 0) continue;
      var end = first;
      while (end < messages.length && messages[end].roundNumber == number) {
        end++;
      }
      result.add(Round(number: number, title: titles[i], start: first, end: end));
    }
    return List.unmodifiable(result);
  }
}

// ---------------------------------------------------------------------------
// المختبر
// ---------------------------------------------------------------------------

/// المؤشرات الأربعة الثابتة. لا تُحسب من الجلسة المختارة.
class LabStats {
  const LabStats({
    required this.totalTests,
    required this.averageScore,
    required this.simulationCostHalalas,
    required this.averageDurationSeconds,
  });

  final int totalTests;
  final int averageScore;
  final int simulationCostHalalas;
  final int averageDurationSeconds;

  String get totalTestsLabel => '$totalTests';
  String get averageScoreLabel => '$averageScore/100';
  String get simulationCostLabel => formatSar(simulationCostHalalas);
  String get averageDurationLabel => '$averageDurationSeconds ث';
}

/// صف في قمع «جاهزية المنتج».
class ReadinessCount {
  const ReadinessCount({required this.stage, required this.count});

  final ReadinessStage stage;
  final int count;
}

/// جلسة مقيَّمة: خمس درجات بترتيب أبعاد «جودة النقاش».
class Evaluation {
  Evaluation({
    required this.id,
    required this.projectId,
    required this.title,
    required this.whenLabel,
    required this.scores,
  }) : assert(scores.length == 5, 'خمس درجات بالضبط');

  final String id;
  final String projectId;
  final String title;
  final String whenLabel;

  /// الدقة، الاتساق، العمق، الوضوح، الالتزام بالطلب (٠–١٠٠).
  final List<int> scores;

  int get average =>
      (scores.fold<int>(0, (sum, s) => sum + s) / scores.length).round();
}

// ---------------------------------------------------------------------------
// الحساب والباقات
// ---------------------------------------------------------------------------

/// رصيد النماذج بالدولار (سنتات). العلاقة الوحيدة: المتبقي + المستهلك = الحد.
class CreditBalance {
  const CreditBalance({
    required this.remainingCents,
    required this.consumedCents,
    required this.limitCents,
  }) : assert(remainingCents + consumedCents == limitCents);

  final int remainingCents;
  final int consumedCents;
  final int limitCents;

  String get remainingLabel => formatUsd(remainingCents);
  String get consumedLabel => formatUsd(consumedCents);
  String get limitLabel => formatUsd(limitCents);

  double get consumedFraction =>
      limitCents == 0 ? 0 : consumedCents / limitCents;
}

class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.priceCents,
    this.quotaText,
    this.badgeText,
    this.isFeatured = false,
  });

  final String id;
  final String name;
  final int priceCents;

  /// اختياري: لا وعود مخترعة خارج المرجع.
  final String? quotaText;
  final String? badgeText;
  final bool isFeatured;

  String get priceLabel => formatUsd(priceCents);
}

class Account {
  const Account({
    required this.displayName,
    required this.currentPlanId,
    required this.credit,
  });

  final String displayName;
  final String currentPlanId;
  final CreditBalance credit;
}
