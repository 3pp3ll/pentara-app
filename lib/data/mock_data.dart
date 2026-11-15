import '../theme/app_colors.dart';
import 'models.dart';

/// كل البيانات التجريبية المحلية.
///
/// ما ورد في المرجع حرفياً: الأعضاء الستة، حالات المشاريع الخمس، أرقام المختبر،
/// الرصيد، الباقات، شارة «آخر جلسة». أما أسماء المشاريع ونص النقاش
/// وأوصافهما فهي بيانات تجريبية مؤلَّفة، وليست من المرجع.
abstract final class MockData {
  // ---- الرئيسية ----------------------------------------------------------

  /// ثابتان: لا DateTime.now().
  static final String homeGreeting = 'مساء الخير، ${account.displayName}';
  static final String homeDateLabel =
      toArabicDigits('الأحد، 15 نوفمبر 2026');

  /// شارة «آخر جلسة: $0.42». ثابت عرض مستقل عن تكاليف البطاقات.
  static const int lastSessionCostCents = 42;
  static String get lastSessionBadge =>
      'آخر جلسة: ${formatUsd(lastSessionCostCents)}';

  /// آخر المشاريع: ثلاثة معرّفات ثابتة لا يغيّرها ترتيب لاحق.
  static const List<String> recentProjectIds = [
    'p-perfume',
    'p-courts',
    'p-health',
  ];

  // ---- الأعضاء -----------------------------------------------------------

  static const List<Member> members = [
    Member(
      id: MemberId.chair,
      title: 'رئيس الجلسة',
      role: 'يدير ويكتب الخلاصة',
      symbol: MemberSymbol.crown,
    ),
    Member(
      id: MemberId.engineer,
      title: 'المهندس',
      role: 'البنية والتنظيم',
      symbol: MemberSymbol.starburst8,
    ),
    Member(
      id: MemberId.practical,
      title: 'العملي',
      role: 'يرتّب التنفيذ',
      symbol: MemberSymbol.linkedRings,
    ),
    Member(
      id: MemberId.analyst,
      title: 'المحلل',
      role: 'البيانات والأرقام',
      symbol: MemberSymbol.star4,
    ),
    Member(
      id: MemberId.challenger,
      title: 'المتحدّي',
      role: 'يراجع المخاطر',
      symbol: MemberSymbol.crosshair,
    ),
    Member(
      id: MemberId.auditor,
      title: 'المدقق',
      role: 'يدقق الصحة',
      symbol: MemberSymbol.doubleDiamond,
    ),
  ];

  static Member memberOf(MemberId id) =>
      members.firstWhere((m) => m.id == id);

  // ---- المشاريع (بترتيب شاشة المشاريع: خمس بطاقات بخمس حالات) -------------

  static const String defaultProjectId = 'p-perfume';

  /// التكاليف أرقام عرض مستقلة: لا تساوي 42 ولا تجمع إلى 260.
  static const List<Project> projects = [
    Project(
      id: 'p-health',
      name: 'تطبيق الوجبات الصحية',
      description: 'تطبيق يقترح وجبات صحية أسبوعية ويربطها بمطابخ محلية.',
      status: ProjectStatus.verified,
      readiness: ReadinessStage.documented,
      costCents: 71,
      mark: 'ص',
    ),
    Project(
      id: 'p-courts',
      name: 'منصة حجز الملاعب',
      description: 'حجز الملاعب الرياضية بالساعة مع تقاسم الدفع بين اللاعبين.',
      status: ProjectStatus.testing,
      readiness: ReadinessStage.tested,
      costCents: 55,
      mark: 'ل',
    ),
    Project(
      id: 'p-study',
      name: 'مساعد المذاكرة',
      description: 'خطة مذاكرة يومية تقيس التقدم وتعدّل الجدول تلقائياً.',
      status: ProjectStatus.needsFix,
      readiness: ReadinessStage.reviewed,
      costCents: 64,
      mark: 'ذ',
    ),
    Project(
      id: 'p-perfume',
      name: 'متجر العطور الفاخرة',
      description: 'متجر إلكتروني للعطور مع توثيق أصالة كل قارورة.',
      status: ProjectStatus.discussing,
      readiness: ReadinessStage.generated,
      costCents: 38,
      mark: 'ع',
    ),
    Project(
      id: 'p-crafts',
      name: 'سوق الحرفيين',
      description: 'سوق يربط الحرفيين المحليين بالمشترين دون وسطاء.',
      status: ProjectStatus.idea,
      readiness: ReadinessStage.generated,
      costCents: 12,
      mark: 'ح',
    ),
  ];

  static Project? projectById(String id) {
    for (final p in projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---- نقاش متجر العطور: ثلاث جولات وخلاصة --------------------------------

  static const List<String> _perfumeRoundTitles = [
    'تحديد النطاق',
    'مراجعة المخاطر',
    'ترتيب التنفيذ',
  ];

  static const List<Message> _perfumeMessages = [
    // ---- الجولة ١ (٤ رسائل). من ينهيها يظهر في مركز الطاولة عند الفتح.
    Message(
      id: 'm01',
      senderId: MemberId.chair,
      roundNumber: 1,
      text: 'نناقش اليوم فكرة متجر إلكتروني للعطور الفاخرة. المطلوب نطاق أولي '
          'واضح، وبنية للمنتج، وخطة تنفيذ بميزانية محدودة.',
    ),
    Message(
      id: 'm02',
      senderId: MemberId.engineer,
      roundNumber: 1,
      text: 'أقترح تنظيم المتجر في أربع وحدات: الكتالوج، والسلة والدفع، '
          'والحسابات، ولوحة إدارة المخزون. نبدأ بالكتالوج والسلة لأنهما '
          'أساس أي بيع.',
      verdict: MessageVerdict.valid,
      reason: 'تقسيم واضح ولا يتعارض مع الطلب.',
    ),
    Message(
      id: 'm03',
      senderId: MemberId.analyst,
      roundNumber: 1,
      text: 'تقديري أن ٤٠٪ من العملاء سيبدؤون بشراء العينات الصغيرة، فنضمّنها '
          'في الباقة الأولى.',
      verdict: MessageVerdict.rejected,
      reason: 'الرقم غير مسنود بمصدر، فلا يُعتمد في الخطة قبل التحقق منه.',
    ),
    Message(
      id: 'm04',
      senderId: MemberId.practical,
      roundNumber: 1,
      text: 'أبدأ بإطلاق تجريبي مصغّر: ٥٠ منتجاً، وبوابة دفع واحدة، وشركة '
          'شحن واحدة، ثم نوسّع بعد قياس الطلب الفعلي.',
      verdict: MessageVerdict.valid,
      reason: 'نطاق قابل للتنفيذ ضمن الميزانية.',
    ),
    // ---- الجولة ٢ (٦ رسائل)
    Message(
      id: 'm05',
      senderId: MemberId.challenger,
      roundNumber: 2,
      text: 'أخشى أن تصبح الأصالة نقطة الضعف: العطور الفاخرة يكثر تقليدها، '
          'ومن دون توثيق المصدر ستفقد الثقة سريعاً.',
      verdict: MessageVerdict.valid,
      reason: 'مخاطرة حقيقية تستحق الإدراج في الخطة.',
    ),
    Message(
      id: 'm06',
      senderId: MemberId.engineer,
      roundNumber: 2,
      text: 'نضيف وحدة توثيق: رقم تسلسلي لكل قارورة، وصفحة تحقق عامة، '
          'وربط ذلك بسجل الموردين.',
      verdict: MessageVerdict.valid,
      reason: 'تعالج المخاطرة المطروحة مباشرة.',
    ),
    Message(
      id: 'm07',
      senderId: MemberId.analyst,
      roundNumber: 2,
      text: 'نقيس النجاح بثلاثة مؤشرات: معدل التحويل، ومتوسط قيمة الطلب، '
          'ونسبة الإرجاع. نحدد المستهدف بعد أسبوعين من البيانات الفعلية.',
      verdict: MessageVerdict.valid,
      reason: 'مؤشرات قابلة للقياس بلا أرقام غير مسنودة.',
    ),
    Message(
      id: 'm08',
      senderId: MemberId.practical,
      roundNumber: 2,
      text: 'نطلق تطبيق الجوال مع المتجر في الأسبوع الأول حتى نصل إلى '
          'العملاء أسرع.',
      verdict: MessageVerdict.rejected,
      reason: 'خارج الطلب: المطلوب متجر ويب في المرحلة الأولى.',
    ),
    Message(
      id: 'm09',
      senderId: MemberId.auditor,
      roundNumber: 2,
      text: 'راجعت الترتيب: الاعتماديات مرتبة، وبوابة الدفع تسبق الشحن، '
          'ولا تعارض بين وحدة التوثيق والكتالوج.',
      verdict: MessageVerdict.valid,
      reason: 'اتساق داخلي سليم.',
    ),
    Message(
      id: 'm10',
      senderId: MemberId.chair,
      roundNumber: 2,
      text: 'نلخّص: متجر ويب بكتالوج من ٥٠ منتجاً مع توثيق أصالة لكل '
          'قارورة. ننتقل إلى الجولة الأخيرة لترتيب الخطة.',
    ),
    // ---- الجولة ٣ (٤ رسائل)
    Message(
      id: 'm11',
      senderId: MemberId.practical,
      roundNumber: 3,
      text: 'الترتيب: أسبوعان للكتالوج والسلة، وأسبوع للدفع والشحن، '
          'وأسبوع للتوثيق، ثم أسبوع اختبار مغلق.',
      verdict: MessageVerdict.valid,
      reason: 'تسلسل منطقي يحترم الاعتماديات.',
    ),
    Message(
      id: 'm12',
      senderId: MemberId.analyst,
      roundNumber: 3,
      text: 'نبدأ جمع المؤشرات الثلاثة من أول أسبوع من الإطلاق التجريبي، ونراجعها مع كل جولة تحسين.',
      verdict: MessageVerdict.valid,
      reason: 'قياس مبكر بلا افتراضات غير مسنودة.',
    ),
    Message(
      id: 'm13',
      senderId: MemberId.challenger,
      roundNumber: 3,
      text: 'أوافق على الترتيب بشرط ألا يُفتح المتجر للعموم قبل اكتمال '
          'اختبار التوثيق على عيّنة من القوارير.',
      verdict: MessageVerdict.valid,
      reason: 'شرط يخفف المخاطرة دون تعطيل الخطة.',
    ),
    Message(
      id: 'm14',
      senderId: MemberId.chair,
      roundNumber: 3,
      text: 'اكتملت الجولات الثلاث. أكتب الآن الخلاصة النهائية.',
    ),
  ];

  /// الخلاصة حقل على سيناريو العطور فقط، مؤلفها رئيس الجلسة.
  static const Summary _perfumeSummary = Summary(
    projectId: 'p-perfume',
    authorId: MemberId.chair,
    title: 'خلاصة مشروع متجر العطور الفاخرة',
    points: [
      'متجر ويب بكتالوج أولي من ٥٠ منتجاً، دون تطبيق جوال في المرحلة الأولى.',
      'وحدة توثيق: رقم تسلسلي لكل قارورة وصفحة تحقق عامة.',
      'ثلاثة مؤشرات للنجاح: معدل التحويل، ومتوسط قيمة الطلب، ونسبة الإرجاع.',
      'أربعة أسابيع: الكتالوج والسلة، ثم الدفع والشحن، ثم التوثيق، ثم اختبار مغلق.',
      'لا فتح للعموم قبل اكتمال اختبار التوثيق على عيّنة من القوارير.',
    ],
    readiness: ReadinessStage.reviewed,
  );

  static final Discussion perfumeScenario = Discussion(
    projectId: 'p-perfume',
    roundTitles: _perfumeRoundTitles,
    messages: _perfumeMessages,
    summary: _perfumeSummary,
  );

  /// المشاريع بلا سيناريو لا تعرض نقاش العطور تحت اسم آخر.
  static Discussion? scenarioOf(String projectId) =>
      projectId == perfumeScenario.projectId ? perfumeScenario : null;

  // ---- المختبر -------------------------------------------------------------

  /// المؤشرات الأربعة ثوابت مستقلة: لا تُحسب من الجلسة المختارة.
  static const LabStats labMetrics = LabStats(
    totalTests: 12,
    averageScore: 87,
    simulationCostHalalas: 1860,
    averageDurationSeconds: 42,
  );

  /// أبعاد «جودة النقاش» بالترتيب الملزم.
  static const List<String> qualityDimensions = [
    'الدقة',
    'الاتساق',
    'العمق',
    'الوضوح',
    'الالتزام بالطلب',
  ];

  /// قمع «جاهزية المنتج»: قيم مستقلة (الـ12 مكرر حرفياً لا متغير مشترك).
  static const List<ReadinessCount> readinessFunnel = [
    ReadinessCount(label: 'مُولَّد', count: 12, tone: StatusTone.neutral),
    ReadinessCount(label: 'مُراجَع', count: 10, tone: StatusTone.info),
    ReadinessCount(label: 'مُختبَر', count: 4, tone: StatusTone.warn),
    ReadinessCount(label: 'موثَّق', count: 3, tone: StatusTone.ok),
  ];

  /// ثلاث جلسات مقيَّمة. الأولى مختارة افتراضياً؛ متوسطها 87 مصادفة بيانات.
  static const List<Evaluation> evaluations = [
    Evaluation(
      id: 'e-perfume',
      projectId: 'p-perfume',
      title: 'جلسة متجر العطور الفاخرة',
      scores: [90, 86, 84, 89, 86],
    ),
    Evaluation(
      id: 'e-courts',
      projectId: 'p-courts',
      title: 'جلسة منصة حجز الملاعب',
      scores: [94, 92, 90, 93, 91],
    ),
    Evaluation(
      id: 'e-study',
      projectId: 'p-study',
      title: 'جلسة مساعد المذاكرة',
      scores: [82, 78, 74, 81, 80],
    ),
  ];

  static const String defaultEvaluationId = 'e-perfume';

  static Evaluation? evaluationById(String id) {
    for (final e in evaluations) {
      if (e.id == id) return e;
    }
    return null;
  }

  // ---- الحساب والباقات -----------------------------------------------------

  /// العلاقة الملزمة الوحيدة: 740 + 260 = 1000 سنت.
  static const Account account = Account(
    displayName: 'عبدالله',
    currentPlanId: 'plan-regular',
    credit: CreditBalance(
      remainingCents: 740,
      consumedCents: 260,
      limitCents: 1000,
    ),
  );

  /// الأسعار المحددة فقط؛ لا حدود أو مزايا مخترعة لـ«ماكس» و«العليا».
  static const List<Plan> plans = [
    Plan(
      id: 'plan-regular',
      name: 'العادية',
      priceCents: 3000,
      quotaText: 'حتى ٢٠ مشروعاً شهرياً',
    ),
    Plan(
      id: 'plan-max',
      name: 'ماكس',
      priceCents: 8000,
    ),
    Plan(
      id: 'plan-top',
      name: 'العليا',
      priceCents: 20000,
      badgeText: 'الأكثر تميزاً',
      isFeatured: true,
    ),
  ];
}
