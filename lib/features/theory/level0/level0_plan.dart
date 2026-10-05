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
    this.trainPracticeSetIds = const [],
  });

  final String lessonId;
  final String title;
  final String primaryCompetency;
  final List<Level0Step> steps;
  final List<String> trainPracticeSetIds;

  factory Level0Plan.fromLesson(Lesson lesson) {
    return Level0Plan(
      lessonId: lesson.id,
      title: lesson.title,
      primaryCompetency: lesson.primaryCompetency,
      trainPracticeSetIds: lesson.level == 6
          ? lesson.practiceSetIds
          : lesson.id == 'L04-04' || lesson.id == 'L04-11'
              ? const ['PR-01']
              : const [],
      steps: switch (lesson.id) {
        'L00-01' => _toneAndNoise(lesson),
        'L00-04' => _loudnessAndTimbre(lesson),
        'L00-07' => _strongBeat(lesson),
        'L02-08' => _anacrusis(lesson),
        'L03-04' => _trebleC4(lesson),
        'L03-10' => _notesAndRhythm(lesson),
        'L10-05' => _rhythmDictationMethod(lesson),
        'L05-01' => _intervalCount(lesson),
        'L08-02' => _majorTriad(lesson),
        'L04-04' || 'L04-11' => _degreeLesson(lesson),
        'L06-01' || 'L06-02' || 'L06-03' || 'L06-04' || 'L06-05' || 'L06-06' || 'L06-07' || 'L06-08' ||
        'L06-09' || 'L06-10' || 'L06-11' =>
          _level6(lesson),
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

List<Level0Step> _degreeLesson(Lesson lesson) {
  const degrees = ['1', '2', '3', '4', '5', '6', '7'];
  return [
    _explanation(lesson),
    for (var i = 0; i < 2; i++)
      _choice(lesson, 'guided', '${lesson.userAction} ${i + 1}', 'T02', degrees, 0),
    _choice(lesson, 'transfer', lesson.finalTask, 'T02', degrees, 0),
  ];
}

List<Level0Step> _trebleC4(Lesson lesson) {
  const notes = ['до', 'ре', 'ми', 'фа', 'соль'];
  return [
    _explanation(lesson),
    _choice(lesson, 'guided', 'Нота C4 на стане', 'T05', notes, 0),
    for (var i = 1; i < lesson.learningItems; i++)
      _choice(lesson, 'guided', 'Нота диапазона C4–G4, шаг ${i + 1}', 'T05', notes, i % notes.length),
    for (var i = 0; i < lesson.checkItems; i++)
      _choice(lesson, 'check', 'Проверка ноты ${i + 1}', 'T05', notes, 0),
    _choice(lesson, 'transfer', lesson.finalTask, 'T05', notes, 0),
  ];
}

List<Level0Step> _majorTriad(Lesson lesson) {
  const options = ['0–4–7', '0–3–7', '0–3–6', '0–4–8'];
  return [
    _explanation(lesson),
    _choice(lesson, 'guided', 'Формула большого трезвучия', 'T07', options, 0),
    _choice(lesson, 'check', 'Какая формула не большая?', 'T07', options, 1),
    _choice(lesson, 'transfer', lesson.finalTask, 'T07', options, 0),
  ];
}

List<Level0Step> _intervalCount(Lesson lesson) {
  const options = ['2', '3', '4'];
  return [
    _explanation(lesson),
    _choice(lesson, 'guided', 'От до до ми', 'T01', options, 1),
    _choice(lesson, 'guided', 'От до до фа', 'T01', options, 2),
    _choice(lesson, 'transfer', lesson.finalTask, 'T01', options, 2),
  ];
}

List<Level0Step> _rhythmDictationMethod(Lesson lesson) {
  const steps = ['сумма сходится', 'сумма не сходится'];
  return [
    _explanation(lesson),
    for (var i = 0; i < 2; i++)
      _choice(lesson, 'guided', '${lesson.userAction}, пример ${i + 1}', 'T08', steps, 0),
    _choice(lesson, 'transfer', lesson.finalTask, 'T08', steps, 0),
  ];
}

List<Level0Step> _notesAndRhythm(Lesson lesson) {
  const steps = ['сначала ритм', 'потом ноты'];
  return [
    _explanation(lesson),
    for (var i = 0; i < lesson.learningItems; i++)
      _choice(lesson, 'guided', '${lesson.userAction}, фраза ${i + 1}', 'T06', steps, 0),
    for (var i = 0; i < lesson.checkItems; i++)
      _choice(lesson, 'check', 'Проверка ${i + 1}', 'T06', steps, 0),
    _choice(lesson, 'transfer', lesson.finalTask, 'T06', steps, 0),
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

List<Level0Step> _level6(Lesson lesson) {
  final (options, answers) = switch (lesson.id) {
    'L06-01' => (
        const [
          ('Третья ступень на 4 полутона', ['мажор', 'минор'], 0),
          ('Третья ступень на 3 полутона', ['мажор', 'минор'], 1),
          ('Минорная третья ступень относительно мажорной', ['выше', 'ниже'], 1),
        ],
        true,
      ),
    'L06-02' => (
        const [
          ('Где полутоны натурального минора', ['2–3 и 5–6', '3–4 и 7–8'], 0),
          ('Ля минор на белых клавишах', ['да', 'нет'], 0),
          ('Формула от тоники', ['тон-полутон-тон-тон-полутон-тон-тон', 'тон-тон-полутон-тон-тон-тон-полутон'], 0),
        ],
        true,
      ),
    'L06-03' => (
        const [
          ('От ля до до', ['3', '4'], 0),
          ('Повышенная VII вместо натуральной', ['другая ступень', 'та же ступень'], 0),
        ],
        true,
      ),
    'L06-04' => (
        const [
          ('Параллель до мажора', ['ля минор', 'до минор'], 0),
          ('Одноимённая к до мажору', ['ля минор', 'до минор'], 1),
        ],
        true,
      ),
    'L06-05' => (
        const [
          ('Что повышено в гармоническом миноре', ['только VII', 'VI и VII'], 0),
        ],
        true,
      ),
    'L06-06' => (
        const [
          ('Мелодический минор вверх', ['VI и VII', 'только VII'], 0),
          ('Мелодический минор вниз', ['натуральный вид', 'повышенные VI и VII'], 0),
        ],
        true,
      ),
    'L06-07' => (
        const [
          ('Порядок диезов', ['фа-до-соль', 'соль-до-фа'], 0),
          ('Два диеза', ['ре мажор', 'соль мажор'], 0),
        ],
        true,
      ),
    'L06-08' => (
        const [
          ('Квинта вверх от до', ['соль', 'фа'], 0),
          ('Сколько диезов у соль мажора', ['1', '2'], 0),
        ],
        true,
      ),
    'L06-09' => (
        const [
          ('Один диез при ключе', ['соль мажор', 'фа мажор'], 0),
        ],
        true,
      ),
    'L06-10' => (
        const [
          ('Большая секунда вверх от до', ['ре', 'ми'], 0),
        ],
        true,
      ),
    'L06-11' => (
        const [
          ('Ступень 5 после переноса в другую тональность', ['5', '1'], 0),
        ],
        true,
      ),
    _ => (const <(String, List<String>, int)>[], false),
  };
  if (!answers) return _fromParams(lesson);
  return [
    _explanation(lesson),
    for (var i = 0; i < options.length; i++)
      _choice(
        lesson,
        i == options.length - 1 ? 'transfer' : 'guided',
        i == options.length - 1 ? lesson.finalTask : options[i].$1,
        lesson.interactionTemplate,
        options[i].$2,
        options[i].$3,
      ),
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
