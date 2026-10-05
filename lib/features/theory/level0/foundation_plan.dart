import '../../curriculum/models/lesson.dart';
import '../../practice/trainers/rhythm_dictation.dart';
import '../../scales/utils/solfege_notes.dart';
import 'late_level_plan.dart';
import 'level0_plan.dart';

/// Сравнение двух высот: выше, ниже или та же.
String pitchRelation(int from, int to) {
  if (to > from) return 'выше';
  if (to < from) return 'ниже';
  return 'так же';
}

/// Сравнение двух длительностей по имени из ритмического словаря.
String durationRelation(String subject, String reference) {
  final left = RhythmDictation.beats[subject]!;
  final right = RhythmDictation.beats[reference]!;
  if (left < right) return 'короче';
  if (left > right) return 'дольше';
  return 'так же';
}

/// Контур нескольких высот.
String contourOf(List<int> midi) {
  var up = false;
  var down = false;
  for (var i = 0; i < midi.length - 1; i++) {
    if (midi[i + 1] > midi[i]) up = true;
    if (midi[i + 1] < midi[i]) down = true;
  }
  if (up && down) return 'с поворотом';
  if (up) return 'вверх';
  if (down) return 'вниз';
  return 'на месте';
}

/// Белая клавиша слева от группы из двух чёрных — до.
String whiteLeftOfTwoBlacks() {
  final white =
      SolfegeNotes.naturalPitchClasses.lastWhere((pitch) => pitch < 1);
  return SolfegeNotes.fromMidi(white, useFlats: false);
}

/// Уроки уровней 0–1, где раньше верный слог выбирался номером задания.
List<Level0Step>? foundationSteps(Lesson lesson) {
  final script = foundationScript(lesson.id);
  if (script == null) return null;
  final transfer = script.transfer ?? script.guided;
  return [
    Level0Step(
        kind: 'explanation', body: lesson.plainExplanation, templateId: 'text'),
    _step(lesson, 'guided', script.guided.question, script.guided),
    _step(
      lesson,
      'transfer',
      identical(transfer, script.guided) ? lesson.finalTask : transfer.question,
      transfer,
    ),
  ];
}

LessonScript? foundationScript(String id) {
  return switch (id) {
    'L00-02' => LessonScript(
        guided: LessonChoice(
          question: 'Ми относительно до',
          right: pitchRelation(60, 64),
          wrong: 'ниже',
        ),
        transfer: LessonChoice(
          question: 'До относительно до',
          right: pitchRelation(60, 60),
          wrong: 'выше',
        ),
      ),
    'L00-03' => LessonScript(
        guided: LessonChoice(
          question: 'Восьмая относительно четверти',
          right: durationRelation('восьмая', 'четверть'),
          wrong: 'дольше',
        ),
        transfer: LessonChoice(
          question: 'Половинная относительно четверти',
          right: durationRelation('половинная', 'четверть'),
          wrong: 'короче',
        ),
      ),
    'L00-05' => LessonScript(
        guided: LessonChoice(
          question: 'Контур до–ре–ми',
          right: contourOf(const [60, 62, 64]),
          wrong: 'вниз',
        ),
        transfer: LessonChoice(
          question: 'Контур ми–ре–фа',
          right: contourOf(const [64, 62, 65]),
          wrong: 'вверх',
        ),
      ),
    'L00-08' => LessonScript(
        guided: LessonChoice(
          question: 'Белая клавиша слева от двух чёрных',
          right: whiteLeftOfTwoBlacks(),
          wrong: SolfegeNotes.naturalNames[1],
        ),
        transfer: LessonChoice(
          question: 'Следующая белая после до',
          right: SolfegeNotes.naturalNames[1],
          wrong: SolfegeNotes.naturalNames[0],
        ),
      ),
    'L01-02' => LessonScript(
        guided: LessonChoice(
          question: 'Четвёртый звук звукоряда',
          right: SolfegeNotes.naturalNames[3],
          wrong: SolfegeNotes.naturalNames[0],
        ),
        transfer: LessonChoice(
          question: 'Седьмой звук звукоряда',
          right: SolfegeNotes.naturalNames[6],
          wrong: SolfegeNotes.naturalNames[3],
        ),
      ),
    'L01-04' => LessonScript(
        guided: LessonChoice(
          question: 'Слог звука на 12 полутонов выше до',
          right: SolfegeNotes.fromMidi(72, useFlats: false),
          wrong: 'ре',
        ),
        transfer: const LessonChoice(
          question: 'Сколько полутонов в октаве?',
          right: 72 - 60 == 12 ? '12' : 'ошибка',
          wrong: '7',
        ),
      ),
    'L01-05' => const LessonScript(
        guided: LessonChoice(
          question: 'Ми–фа',
          right: 65 - 64 == 1 ? 'полутон' : 'ошибка',
          wrong: 'тон',
        ),
        transfer: LessonChoice(
          question: 'До–ре',
          right: 62 - 60 == 2 ? 'тон' : 'ошибка',
          wrong: 'полутон',
        ),
      ),
    'L01-06' => const LessonScript(
        guided: LessonChoice(
          question: 'Где естественный полутон?',
          right: 65 - 64 == 1 && 62 - 60 == 2 ? 'ми–фа' : 'ошибка',
          wrong: 'до–ре',
        ),
        transfer: LessonChoice(
          question: 'Си–до',
          right: 72 - 71 == 1 ? 'полутон' : 'ошибка',
          wrong: 'тон',
        ),
      ),
    'L01-07' => LessonScript(
        guided: LessonChoice(
          question: 'До с диезом',
          right: SolfegeNotes.fromMidi(61, useFlats: false),
          wrong: 'до',
        ),
        transfer: LessonChoice(
          question: 'Тот же звук, записанный бемолем',
          right: SolfegeNotes.fromMidi(61, useFlats: true),
          wrong: 'ре',
        ),
      ),
    _ => null,
  };
}

Level0Step _step(Lesson lesson, String kind, String body, LessonChoice choice) {
  return Level0Step(
    kind: kind,
    body: body,
    templateId: 'T02',
    options: [choice.right, choice.wrong],
    correctIndex: 0,
    feedbackCorrect: lesson.feedbackCorrect,
    feedbackError: lesson.feedbackFirstError,
  );
}
