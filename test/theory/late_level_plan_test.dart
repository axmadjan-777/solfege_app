import 'dart:convert';
import 'dart:io';

import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/trainers/harmony_and_melody.dart';
import 'package:solfege_app/features/practice/trainers/modes_and_sevenths.dart';
import 'package:solfege_app/features/practice/trainers/rhythm_advanced.dart';
import 'package:solfege_app/features/practice/trainers/scale_keys.dart' as keys;
import 'package:solfege_app/features/practice/trainers/v2_analysis.dart';
import 'package:solfege_app/features/theory/level0/late_level_plan.dart';
import 'package:solfege_app/features/theory/level0/level0_plan.dart';
import 'package:solfege_app/features/theory/screens/theory_level_screen.dart';
import 'package:test/test.dart';

void main() {
  late CurriculumCatalog catalog;

  setUpAll(() {
    catalog = CurriculumCatalog.fromDecoded(
      levels: _read('levels.json'),
      sourceMap: _read('source-map.json'),
      audioManifest: _read('audio-manifest.json'),
      exercises: _read('exercises.json'),
      competencies: _read('competencies.json'),
      lessons: _read('lessons.json'),
    );
  });

  test('levels 6, 7, 9 and 11 are on the theory list and keep the card text',
      () {
    final shown = catalog.lessons
        .where(showsOnTheoryList)
        .map((lesson) => lesson.id)
        .toSet();
    expect(
        shown,
        containsAll([
          'L05-05',
          'L06-01',
          'L07-08',
          'L08-11',
          'L09-08',
          'L10-08',
          'L11-13'
        ]));

    final late =
        catalog.lessons.where((lesson) => lateLevelSteps(lesson) != null);
    expect(late, hasLength(56));
    for (final lesson in late) {
      final plan = Level0Plan.fromLesson(lesson);
      final script = lessonScript(lesson.id);
      expect(plan.lessonId, lesson.id);
      expect(plan.steps, hasLength(3));
      expect(plan.steps.first.body, lesson.plainExplanation);
      expect(plan.steps[1].options[plan.steps[1].correctIndex],
          script.guided.right);
      expect(script.guided.right, isNot('ошибка'));
      expect(script.guided.right, isNot(script.guided.wrong));
      final transfer = script.transfer ?? script.guided;
      expect(plan.steps.last.options[plan.steps.last.correctIndex],
          transfer.right);
      expect(transfer.right, isNot('ошибка'));
    }
  });

  test('minor cards follow the three minor forms and the circle of fifths', () {
    final harmonic = keys.stepsOf(keys.MinorForm.harmonic);
    expect(keys.onlySeventhRaised(harmonic), isTrue);
    expect(keys.degreeOffset(harmonic, 6), 8);
    expect(keys.degreeOffset(harmonic, 7), 11);
    expect(keys.sixthAndSeventhRaised(keys.stepsOf(keys.MinorForm.melodic)),
        isTrue);
    expect(keys.gSharpBeforeCSharp(const ['фа', 'соль', 'до']), isTrue);
    expect(
        keys.gSharpBeforeCSharp(keys.signaturePrefix(sharps: true, count: 3)),
        isFalse);
    expect(keys.isRelativeMinor('до', 'ля'), isTrue);
    expect(keys.isParallelMinor('до', 'до'), isTrue);
    expect(keys.isRelativeMinor('до', 'до'), isFalse);
    String choiceOf(String id) {
      final step = Level0Plan.fromLesson(catalog.lesson(id))
          .steps
          .firstWhere((step) => !step.isExplanation);
      return step.options[step.correctIndex];
    }

    expect(choiceOf('L06-05'), 'только VII');
    expect(choiceOf('L06-06'), 'VI и VII');
    expect(choiceOf('L06-04'), 'ля минор');
    expect(choiceOf('L06-10'), 'ре');
  });

  test('rhythm, cadence and v2 cards keep the rule names', () {
    expect(isSyncopated(const [true, false, true, false]), isFalse);
    expect(eighthsInMeter('6/8'), eighthsInMeter('3/4'));
    expect(beatGroups('6/8'), [3, 3]);
    expect(beatGroups('3/4'), [2, 2, 2]);
    expect(cadenceType(const ['I', 'V']), 'half');
    expect(cadenceType(const ['IV', 'I']), 'plagal');
    expect(noteBelongsToChord(65, romanTriad('I', tonic: 60)), isFalse);
    expect(hasModulated(60, 72), isFalse);
    expect(hasModulated(60, 67), isTrue);
    expect(modeBySteps(modes['эолийский']!), 'эолийский');
    expect(modes['эолийский']![5], 8);
    expect(tonicTriadMelody(const [1, 3, 5, 2]), isFalse);

    expect(_right('L07-01'), '1/4 четверти');
    expect(_right('L07-02'), 'четверть');
    expect(_right('L07-03'), 'четверть');
    expect(_right('L07-04'), 'синкопа');
    expect(_right('L07-05'), 'одна четверть');
    expect(_right('L07-06'), 'две доли');
    expect(_right('L07-07'), 'разная группировка');
    expect(_right('L07-08'), '5/4');
    expect(_right('L09-01'), 'соль');
    expect(_right('L09-02'), 'си');
    expect(_right('L09-03'), 'автентическая');
    expect(_right('L09-04'), 'прерванная');
    expect(lessonScript('L09-04').transfer!.right, 'плагальная');
    expect(_right('L09-05'), 'IV');
    expect(_right('L09-06'), 'автентическая');
    expect(_right('L09-07'), 'входит');
    expect(lessonScript('L09-07').transfer!.right, 'не входит');
    expect(_right('L09-08'), 'соль');
    expect(_right('L11-01'), '4 звука');
    expect(_right('L11-02'), '0–4–7–10');
    expect(_right('L11-03'), 'ми');
    expect(_right('L11-04'), '0–3–6–9');
    expect(_right('L11-05'), 'dim7');
    expect(_right('L11-06'), 'дорийский');
    expect(_right('L11-07'), 'VII');
    expect(_right('L11-08'), '5 звуков');
    expect(_right('L11-09'), 'полутон');
    expect(_right('L11-10'), 'ре');
    expect(_right('L11-11'), 'модуляция');
    expect(_right('L11-12'), 'V в до и I в соль');
    expect(_right('L11-13'), 'замкнута');
    expect(_right('L05-02'), '7');
    expect(lessonScript('L05-02').transfer!.right, '5');
    expect(_right('L05-03'), 'большая');
    expect(_right('L05-04'), 'большая');
    expect(_right('L05-05'), '9');
    expect(lessonScript('L05-05').transfer!.right, '10');
    expect(_right('L05-06'), '0');
    expect(lessonScript('L05-06').transfer!.right, '12');
    expect(_right('L05-07'), 'ми');
    expect(_right('L05-08'), 'до');
    expect(_right('L05-09'), 'б6');
    expect(_right('L05-10'), 'вместе');
    expect(_right('L05-11'), '6');
    expect(lessonScript('L05-11').transfer!.right, 'тритон');
    expect(_right('L08-01'), 'большая, затем малая');
    expect(_right('L08-03'), '0–3–7');
    expect(_right('L08-04'), 'большое');
    expect(_right('L08-05'), '0–3–6');
    expect(_right('L08-06'), '0–4–8');
    expect(_right('L08-07'), 'четыре');
    expect(_right('L08-08'), 'ми');
    expect(_right('L08-09'), 'соль');
    expect(_right('L08-10'), 'минор');
    expect(_right('L08-11'), 'мажор в гармоническом');
    expect(_right('L10-01'), 'можно читать');
    expect(_right('L10-02'), 'до');
    expect(_right('L10-03'), 'скачок по трезвучию');
    expect(lessonScript('L10-03').transfer!.right, 'не по трезвучию');
    expect(_right('L10-04'), '1–3–5–1');
    expect(_right('L10-06'), 'на тонику');
    expect(_right('L10-07'), 'тритон');
    expect(_right('L10-08'), 'самоотчёт');
    expect(Level0Plan.fromLesson(catalog.lesson('L05-01')).steps[1].body,
        'От до до ми');
    expect(
        Level0Plan.fromLesson(catalog.lesson('L08-02')).steps[1].options.first,
        '0–4–7');
  });
}

String _right(String id) => lessonScript(id).guided.right;

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(
      jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
