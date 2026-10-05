enum LessonStepKind { warmup, explanation, guided, check, transfer }

class LessonStep {
  const LessonStep({
    required this.kind,
    required this.body,
    this.options = const [],
    this.correctIndex = 0,
    this.templateId = 'T01',
    this.feedbackCorrect = 'Верно',
    this.feedbackError = 'Пока не то',
  });

  final LessonStepKind kind;
  final String body;
  final List<String> options;
  final int correctIndex;
  final String templateId;
  final String feedbackCorrect;
  final String feedbackError;

  bool get isChoice => options.isNotEmpty;
  bool get allowsHint => kind == LessonStepKind.guided;
}

/// Плеер части 4: 2–3 актуализации, объяснение, 6–12 с подсказкой,
/// 2–4 контрольных без подсказки, одно задание переноса.
class LessonScript {
  const LessonScript({
    required this.title,
    required this.explanationSeconds,
    required this.steps,
    required this.trainLabel,
  });

  final String title;
  final int explanationSeconds;
  final List<LessonStep> steps;
  final String trainLabel;

  factory LessonScript.sampleT01() {
    LessonStep choice(LessonStepKind kind, String body) => LessonStep(
          kind: kind,
          body: body,
          options: const ['Верный ответ', 'Другой'],
          templateId: 'T01',
        );
    return LessonScript(
      title: 'Пробный урок',
      explanationSeconds: 40,
      trainLabel: 'Тренировать',
      steps: [
        const LessonStep(kind: LessonStepKind.explanation, body: 'Тон можно спеть, шум — нет.'),
        choice(LessonStepKind.warmup, 'Повторение 1'),
        choice(LessonStepKind.warmup, 'Повторение 2'),
        for (var i = 1; i <= 6; i++) choice(LessonStepKind.guided, 'Задание $i'),
        choice(LessonStepKind.check, 'Проверка 1'),
        choice(LessonStepKind.check, 'Проверка 2'),
        choice(LessonStepKind.transfer, 'Перенос'),
      ],
    );
  }
}
