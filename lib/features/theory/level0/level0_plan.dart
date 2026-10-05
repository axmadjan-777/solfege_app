import '../../curriculum/models/lesson.dart';
import '../../practice/progress/attempt.dart';
import '../../scales/utils/solfege_notes.dart';

/// Потолок урока. `mastered` ставит только отложенная проверка.
CompetencyStatus statusAfterLesson() => CompetencyStatus.provisionallyPassed;

class Level0Step {
  const Level0Step({
    required this.kind,
    required this.body,
    required this.templateId,
    this.options = const [],
    this.correctIndex = 0,
    this.correctIndexes = const {},
    this.tapsRequired = 0,
    this.feedbackCorrect = '',
    this.feedbackError = '',
  });

  final String kind;
  final String body;
  final String templateId;
  final List<String> options;
  final int correctIndex;
  final Set<int> correctIndexes;
  final int tapsRequired;
  final String feedbackCorrect;
  final String feedbackError;

  bool get isExplanation => kind == 'explanation';
}

class Level0Plan {
  const Level0Plan({
    required this.lessonId,
    required this.title,
    required this.primaryCompetency,
    required this.steps,
  });

  final String lessonId;
  final String title;
  final String primaryCompetency;
  final List<Level0Step> steps;

  factory Level0Plan.fromLesson(Lesson lesson) {
    return Level0Plan(
      lessonId: lesson.id,
      title: lesson.title,
      primaryCompetency: lesson.primaryCompetency,
      steps: switch (lesson.id) {
        'L00-01' => _toneAndNoise(lesson),
        'L00-04' => _loudnessAndTimbre(lesson),
        'L00-07' => _strongBeat(lesson),
        'L02-08' => _anacrusis(lesson),
        _ => lesson.level == 1 ? _level1(lesson) : _fromParams(lesson),
      },
    );
  }
}

const toneNoisePool = {
  'piano': ('фортепиано', true),
  'clap': ('хлопок', false),
  'shaker': ('шейкер', false),
  'voice': ('голос', true),
  'flute': ('флейта', true),
  'table_knock': ('удар по столу', false),
};

const _singable = ['можно спеть', 'нельзя спеть'];

List<Level0Step> _toneAndNoise(Lesson lesson) {
  final pool = _strings(lesson.exerciseParams['sound_pool']);
  final guidedIds = pool.take(lesson.learningItems).toList();
  final checkIds = ['voice', 'table_knock', 'flute', 'clap'].take(lesson.checkItems);
  return [
    _explanation(lesson),
    for (final id in guidedIds) _soundStep(lesson, id, 'guided'),
    for (final id in checkIds) _soundStep(lesson, id, 'check'),
    Level0Step(
      kind: 'transfer',
      body: lesson.finalTask,
      templateId: 'T03',
      options: [for (final id in pool) toneNoisePool[id]!.$1],
      correctIndexes: {
        for (var i = 0; i < pool.length; i++)
          if (toneNoisePool[pool[i]]!.$2) i,
      },
      feedbackCorrect: lesson.feedbackCorrect,
      feedbackError: lesson.feedbackFirstError,
    ),
  ];
}

Level0Step _soundStep(Lesson lesson, String id, String kind) {
  final sound = toneNoisePool[id]!;
  return Level0Step(
    kind: kind,
    body: '${lesson.userAction}: ${sound.$1}',
    templateId: 'T04',
    options: _singable,
    correctIndex: sound.$2 ? 0 : 1,
    feedbackCorrect: lesson.feedbackCorrect,
    feedbackError: lesson.feedbackFirstError,
  );
}

List<Level0Step> _loudnessAndTimbre(Lesson lesson) {
  const loud = ['громче', 'тише'];
  const timbre = ['тот же тембр', 'другой тембр'];
  return [
    _explanation(lesson),
    for (var i = 0; i < 3; i++)
      _choice(lesson, 'guided', 'Сравни громкость, пара ${i + 1}', 'T11', loud, i.isEven ? 0 : 1),
    for (var i = 0; i < 3; i++)
      _choice(lesson, 'guided', 'Найди одинаковый тембр, пара ${i + 1}', 'T11', timbre, 0),
    for (var i = 0; i < lesson.checkItems; i++)
      _choice(lesson, 'check', 'Проверка тембра ${i + 1}', 'T11', timbre, 0),
    _choice(lesson, 'transfer', lesson.finalTask, 'T11', const ['фортепиано', 'гитара', 'флейта', 'электропиано'], 0),
  ];
}

List<Level0Step> _anacrusis(Lesson lesson) {
  const answers = ['есть затакт', 'нет затакта'];
  return [
    _explanation(lesson),
    for (var i = 0; i < lesson.learningItems; i++)
      _choice(lesson, 'guided', 'Мелодия ${i + 1}: есть затакт?', 'T02', answers, i.isEven ? 0 : 1),
    for (var i = 0; i < lesson.checkItems; i++)
      _choice(lesson, 'check', 'Проверка затакта ${i + 1}', 'T02', answers, 0),
    Level0Step(
      kind: 'transfer',
      body: lesson.finalTask,
      templateId: 'T03',
      options: const ['мелодия 1', 'мелодия 2', 'мелодия 3', 'мелодия 4'],
      correctIndexes: const {0, 2},
      feedbackCorrect: lesson.feedbackCorrect,
      feedbackError: lesson.feedbackFirstError,
    ),
  ];
}

List<Level0Step> _strongBeat(Lesson lesson) {
  const meter = ['на два', 'на три'];
  return [
    _explanation(lesson),
    for (var i = 0; i < lesson.learningItems; i++)
      _choice(lesson, 'guided', '${lesson.userAction}, фрагмент ${i + 1}', 'T02', meter, i.isEven ? 1 : 0),
    for (var i = 0; i < lesson.checkItems; i++)
      _choice(lesson, 'check', 'Проверка размера ${i + 1}', 'T02', meter, 1),
    _choice(lesson, 'transfer', lesson.finalTask, 'T02', meter, 1),
  ];
}

List<Level0Step> _fromParams(Lesson lesson) {
  if (lesson.id == 'L00-06') return _pulse(lesson);
  final options = _optionsFor(lesson);
  return [
    _explanation(lesson),
    for (var i = 0; i < lesson.learningItems; i++)
      _choice(lesson, 'guided', '${lesson.userAction} ${i + 1}', lesson.interactionTemplate, options, i % options.length),
    for (var i = 0; i < lesson.checkItems; i++)
      _choice(lesson, 'check', 'Проверка ${i + 1}', lesson.interactionTemplate, options, 0),
    _choice(lesson, 'transfer', lesson.finalTask, lesson.interactionTemplate, options, 0),
  ];
}

List<Level0Step> _pulse(Lesson lesson) {
  final tempos = _ints(lesson.exerciseParams['tempo_bpm']);
  return [
    _explanation(lesson),
    for (var i = 0; i < lesson.learningItems; i++)
      Level0Step(
        kind: 'guided',
        body: 'Тапни вместе с пульсом ${tempos[i % tempos.length]} BPM',
        templateId: 'T09',
        tapsRequired: 4,
        feedbackCorrect: lesson.feedbackCorrect,
        feedbackError: lesson.feedbackFirstError,
      ),
    for (var i = 0; i < lesson.checkItems; i++)
      Level0Step(
        kind: 'check',
        body: 'Удержи пульс, проверка ${i + 1}',
        templateId: 'T09',
        tapsRequired: 4,
        feedbackCorrect: lesson.feedbackCorrect,
        feedbackError: lesson.feedbackFirstError,
      ),
    Level0Step(
      kind: 'transfer',
      body: lesson.finalTask,
      templateId: 'T09',
      tapsRequired: 4,
      feedbackCorrect: lesson.feedbackCorrect,
      feedbackError: lesson.feedbackFirstError,
    ),
  ];
}

Level0Step _explanation(Lesson lesson) => Level0Step(
      kind: 'explanation',
      body: lesson.plainExplanation,
      templateId: 'text',
    );

Level0Step _choice(
  Lesson lesson,
  String kind,
  String body,
  String templateId,
  List<String> options,
  int correctIndex,
) {
  return Level0Step(
    kind: kind,
    body: body,
    templateId: templateId,
    options: options,
    correctIndex: correctIndex,
    feedbackCorrect: lesson.feedbackCorrect,
    feedbackError: lesson.feedbackFirstError,
  );
}

List<String> _optionsFor(Lesson lesson) {
  return switch (lesson.id) {
    'L00-02' => const ['выше', 'ниже', 'так же'],
    'L00-03' => const ['короче', 'дольше'],
    'L00-05' => const ['вверх', 'вниз', 'на месте', 'с поворотом'],
    'L00-08' => const ['до', 'ре', 'ми'],
    _ => const ['да', 'нет'],
  };
}

/// Слог → буква. Си = B, буква H не используется.
String letterForSyllable(String syllable) {
  const letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  final index = SolfegeNotes.naturalNames.indexOf(syllable);
  if (index < 0) {
    throw ArgumentError.value(syllable, 'syllable', 'Неизвестное слоговое имя');
  }
  return letters[index];
}

List<Level0Step> _level1(Lesson lesson) {
  return switch (lesson.id) {
    'L01-01' => _doReMi(lesson),
    'L01-03' => _letterPairs(lesson),
    _ => _level1Generic(lesson),
  };
}

List<Level0Step> _doReMi(Lesson lesson) {
  final notes = SolfegeNotes.naturalNames.take(3).toList();
  return [
    _explanation(lesson),
    for (var i = 0; i < lesson.learningItems; i++)
      _choice(lesson, 'guided', 'Найти клавишу: ${notes[i % notes.length]}', 'T06', notes, i % notes.length),
    for (var i = 0; i < lesson.checkItems; i++)
      _choice(lesson, 'check', 'Назови клавишу ${i + 1}', 'T06', notes, i % notes.length),
    _choice(
      lesson,
      'transfer',
      lesson.finalTask,
      'T06',
      const ['до, ми, ре', 'ре, до, ми', 'ми, ре, до'],
      0,
    ),
  ];
}

List<Level0Step> _letterPairs(Lesson lesson) {
  const syllables = SolfegeNotes.naturalNames;
  return [
    _explanation(lesson),
    for (final syllable in syllables)
      _choice(
        lesson,
        'guided',
        'Буква для «$syllable»',
        'T11',
        [for (final name in syllables) letterForSyllable(name)],
        syllables.indexOf(syllable),
      ),
    _choice(lesson, 'transfer', lesson.finalTask, 'T11', [letterForSyllable('си')], 0),
  ];
}

List<Level0Step> _level1Generic(Lesson lesson) {
  const notes = SolfegeNotes.naturalNames;
  return [
    _explanation(lesson),
    for (var i = 0; i < lesson.learningItems; i++)
      _choice(lesson, 'guided', '${lesson.userAction} ${i + 1}', lesson.interactionTemplate, notes, i % notes.length),
    for (var i = 0; i < lesson.checkItems; i++)
      _choice(lesson, 'check', 'Проверка ${i + 1}', lesson.interactionTemplate, notes, 0),
    _choice(lesson, 'transfer', lesson.finalTask, lesson.interactionTemplate, notes, 0),
  ];
}

List<String> _strings(Object? raw) => [for (final value in raw as List? ?? const []) value.toString()];

List<int> _ints(Object? raw) => [for (final value in raw as List? ?? const []) (value as num).toInt()];
