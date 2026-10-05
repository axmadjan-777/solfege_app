import '../../curriculum/models/lesson.dart';
import '../../interaction/templates/scale_builder_template.dart';
import '../../practice/trainers/degree_dictation.dart';
import '../../practice/trainers/interval_ear.dart';
import '../../practice/trainers/note_reading.dart';
import '../../practice/trainers/rhythm_advanced.dart';
import '../../practice/trainers/rhythm_dictation.dart';
import '../../practice/trainers/scale_keys.dart' as keys;
import '../../practice/trainers/sight_reading.dart';
import '../../scales/utils/solfege_notes.dart';
import '../../scales/utils/treble_staff_layout.dart';
import 'late_level_plan.dart';
import 'level0_plan.dart';

/// Уроки уровней 2–4, которые раньше отвечали «да/нет».
List<Level0Step>? earlyLevelSteps(Lesson lesson) {
  final script = earlyScript(lesson.id);
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

LessonScript? earlyScript(String id) {
  return switch (id) {
    'L02-01' => LessonScript(
        guided: LessonChoice(
          question: 'Сколько долей длится четверть?',
          right:
              RhythmDictation.beats['четверть'] == 1 ? 'одна доля' : 'ошибка',
          wrong: 'две доли',
        ),
      ),
    'L02-02' => LessonScript(
        guided: LessonChoice(
          question: 'Две четверти заполняют',
          right: RhythmDictation.barFits(const ['четверть', 'четверть'],
                  beatsInBar: 2)
              ? '2/4'
              : 'ошибка',
          wrong: '3/4',
        ),
        transfer: LessonChoice(
          question: 'Три четверти заполняют',
          right: RhythmDictation.barFits(
                  const ['четверть', 'четверть', 'четверть'],
                  beatsInBar: 3)
              ? '3/4'
              : 'ошибка',
          wrong: '2/4',
        ),
      ),
    'L02-03' => LessonScript(
        guided: LessonChoice(
          question: 'Четыре четверти заполняют',
          right: RhythmDictation.barFits(
                  const ['четверть', 'четверть', 'четверть', 'четверть'],
                  beatsInBar: 4)
              ? '4/4'
              : 'ошибка',
          wrong: '3/4',
        ),
      ),
    'L02-04' => LessonScript(
        guided: LessonChoice(
          question: 'Что длиннее: половинная или четверть?',
          right: RhythmDictation.beats['половинная']! >
                  RhythmDictation.beats['четверть']!
              ? 'половинная'
              : 'ошибка',
          wrong: 'четверть',
        ),
      ),
    'L02-05' => LessonScript(
        guided: LessonChoice(
          question: 'Две восьмые вместе длятся как',
          right: RhythmDictation.sum(const ['восьмая', 'восьмая']) == 1
              ? 'четверть'
              : 'ошибка',
          wrong: 'половинная',
        ),
        transfer: LessonChoice(
          question: 'Одна восьмая относительно четверти',
          right: RhythmDictation.beats['восьмая']! <
                  RhythmDictation.beats['четверть']!
              ? 'короче'
              : 'ошибка',
          wrong: 'длиннее',
        ),
      ),
    'L02-06' => LessonScript(
        guided: LessonChoice(
          question: 'Четвертная пауза длится',
          right: RhythmDictation.beats['четвертная пауза'] ==
                  RhythmDictation.beats['четверть']
              ? 'как четверть'
              : 'ошибка',
          wrong: 'как восьмая',
        ),
      ),
    'L02-07' => LessonScript(
        guided: LessonChoice(
          question: 'Четверть с точкой длится',
          right: dottedValue(quarter) == 1.5 ? 'полторы четверти' : 'ошибка',
          wrong: 'две четверти',
        ),
      ),
    'L03-01' => const LessonScript(
        guided: LessonChoice(
          question: 'Сколько линеек у нотного стана?',
          right: TrebleStaffLayout.lineCount == 5 &&
                  TrebleStaffLayout.referenceLineIndex <
                      TrebleStaffLayout.lineCount
              ? '5'
              : 'ошибка',
          wrong: '4',
        ),
      ),
    'L03-02' => LessonScript(
        guided: LessonChoice(
          question: 'Опорная нота скрипичного ключа',
          right: NoteReading.syllable(NoteReading.g4Midi) == 'соль' &&
                  TrebleStaffLayout.referenceMidi == NoteReading.g4Midi
              ? 'соль'
              : 'ошибка',
          wrong: 'фа',
        ),
      ),
    'L03-03' => LessonScript(
        guided: LessonChoice(
          question: 'Три опоры скрипичного ключа',
          right: _threeAnchors(),
          wrong: 'фа, ля, фа',
        ),
      ),
    'L03-05' => LessonScript(
        guided: LessonChoice(
          question: 'Нота A4',
          right: NoteReading.syllable(69) == 'ля' ? 'ля' : 'ошибка',
          wrong: 'соль',
        ),
      ),
    'L03-06' => LessonScript(
        guided: LessonChoice(
          question: 'Штиль у до первой октавы',
          right: NoteReading.stemUp(NoteReading.c4Midi) ? 'вверх' : 'ошибка',
          wrong: 'вниз',
        ),
      ),
    'L03-07' => LessonScript(
        guided: LessonChoice(
          question: 'Опорная нота басового ключа',
          right: NoteReading.bassStepsFromF3(NoteReading.f3Midi) == 0 &&
                  NoteReading.syllable(NoteReading.f3Midi) == 'фа'
              ? 'фа'
              : 'ошибка',
          wrong: 'соль',
        ),
      ),
    'L03-08' => LessonScript(
        guided: LessonChoice(
          question: 'Нота C3 в басовом ключе',
          right: NoteReading.inBassC3C4(NoteReading.c3Midi) &&
                  NoteReading.syllable(NoteReading.c3Midi) == 'до'
              ? 'до'
              : 'ошибка',
          wrong: 'фа',
        ),
      ),
    'L03-09' => LessonScript(
        guided: LessonChoice(
          question: 'Среднее до принадлежит',
          right: NoteReading.inTrebleC4G4(NoteReading.c4Midi) &&
                  NoteReading.inBassC3C4(NoteReading.c4Midi)
              ? 'обоим ключам'
              : 'ошибка',
          wrong: 'только скрипичному',
        ),
      ),
    'L04-01' => LessonScript(
        guided: LessonChoice(
          question: 'От ми до фа',
          right: IntervalEar.semitones['м2'] == 1 && 65 - 64 == 1
              ? 'полутон'
              : 'ошибка',
          wrong: 'тон',
        ),
      ),
    'L04-02' => LessonScript(
        guided: LessonChoice(
          question: 'Диез повышает ноту',
          right: NoteReading.syllable(66) == 'фа-диез' && 66 - 65 == 1
              ? 'на полутон'
              : 'ошибка',
          wrong: 'на тон',
        ),
      ),
    'L04-03' => LessonScript(
        guided: LessonChoice(
          question: 'До-диез звучит так же, как',
          right: SolfegeNotes.fromMidi(61, useFlats: false) == 'до-диез' &&
                  SolfegeNotes.fromMidi(61, useFlats: true) == 'ре-бемоль'
              ? 'ре-бемоль'
              : 'ошибка',
          wrong: 'ре',
        ),
      ),
    'L04-05' => LessonScript(
        guided: LessonChoice(
          question: 'Формула мажора',
          right: isMajorScale(majorScaleSteps)
              ? majorScaleSteps.join('–')
              : 'ошибка',
          wrong: 'полутон–тон–тон–тон–тон–тон–полутон',
        ),
      ),
    'L04-06' => LessonScript(
        guided: LessonChoice(
          question: 'Знаки до мажора',
          right: keys.signatureCount('до') == 0 ? 'без знаков' : 'ошибка',
          wrong: 'один диез',
        ),
      ),
    'L04-07' => LessonScript(
        guided: LessonChoice(
          question: 'I ступень до мажора',
          right: DegreeDictation.degreeNumber(60, 60) == 1 ? 'до' : 'ошибка',
          wrong: 'ре',
        ),
      ),
    'L04-08' => LessonScript(
        guided: LessonChoice(
          question: 'Устойчивые ступени',
          right: SightPhrase.stable.containsAll(const {1, 3, 5}) &&
                  SightPhrase.stable.length == 3
              ? 'I, III, V'
              : 'ошибка',
          wrong: 'II, IV, VI',
        ),
      ),
    'L04-09' => LessonScript(
        guided: LessonChoice(
          question: 'Куда тяготеет VII ступень?',
          right: DegreeDictation.semitones[6] == 11 ? 'в I' : 'ошибка',
          wrong: 'в IV',
        ),
      ),
    'L04-10' => LessonScript(
        guided: LessonChoice(
          question: 'Мажор с одним диезом',
          right: keys.signatureCount('соль') == 1 &&
                  keys.majorFromSharpCount(1) == 'соль'
              ? 'соль мажор'
              : 'ошибка',
          wrong: 'фа мажор',
        ),
        transfer: LessonChoice(
          question: 'Мажор с одним бемолем',
          right: keys.majorFromFlatCount(1) == 'фа' ? 'фа мажор' : 'ошибка',
          wrong: 'соль мажор',
        ),
      ),
    _ => null,
  };
}

String _threeAnchors() {
  final names = [
    NoteReading.syllable(60),
    NoteReading.syllable(67),
    NoteReading.syllable(72)
  ];
  final named = names[0] == 'до' && names[1] == 'соль' && names[2] == 'до';
  return named ? names.join(', ') : 'ошибка';
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
