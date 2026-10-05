import 'dart:convert';
import 'dart:io';

import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/scales/utils/solfege_notes.dart';
import 'package:solfege_app/features/theory/level0/foundation_plan.dart';
import 'package:solfege_app/features/theory/level0/level0_plan.dart';
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

  test('pitch, duration and contour come from the sounds, not the item number',
      () {
    expect(pitchRelation(60, 64), 'выше');
    expect(pitchRelation(64, 60), 'ниже');
    expect(pitchRelation(60, 60), 'так же');
    expect(durationRelation('восьмая', 'четверть'), 'короче');
    expect(durationRelation('половинная', 'четверть'), 'дольше');
    expect(contourOf(const [60, 62, 64]), 'вверх');
    expect(contourOf(const [64, 62, 60]), 'вниз');
    expect(contourOf(const [64, 62, 65]), 'с поворотом');
    expect(contourOf(const [60, 60]), 'на месте');
    expect(whiteLeftOfTwoBlacks(), 'до');

    final lessons =
        catalog.lessons.where((lesson) => foundationSteps(lesson) != null);
    expect(lessons.map((lesson) => lesson.id), [
      'L00-02',
      'L00-03',
      'L00-05',
      'L00-08',
      'L01-02',
      'L01-04',
      'L01-05',
      'L01-06',
      'L01-07',
    ]);
    for (final lesson in lessons) {
      final plan = Level0Plan.fromLesson(lesson);
      final script = foundationScript(lesson.id)!;
      expect(plan.steps.first.body, lesson.plainExplanation);
      expect(plan.steps[1].options[plan.steps[1].correctIndex],
          script.guided.right);
      expect(script.guided.right, isNot(script.guided.wrong));
      expect(script.guided.right, isNot('ошибка'));
    }

    expect(foundationScript('L00-02')!.guided.right, 'выше');
    expect(foundationScript('L00-02')!.transfer!.right, 'так же');
    expect(foundationScript('L00-03')!.guided.right, 'короче');
    expect(foundationScript('L00-05')!.transfer!.right, 'с поворотом');
    expect(foundationScript('L00-08')!.transfer!.right, 'ре');
    expect(foundationScript('L01-02')!.guided.right, 'фа');
    expect(foundationScript('L01-02')!.transfer!.right, 'си');
    expect(foundationScript('L01-04')!.guided.right, 'до');
    expect(foundationScript('L01-04')!.transfer!.right, '12');
    expect(foundationScript('L01-05')!.guided.right, 'полутон');
    expect(foundationScript('L01-05')!.transfer!.right, 'тон');
    expect(foundationScript('L01-06')!.guided.right, 'ми–фа');
    expect(foundationScript('L01-07')!.guided.right, 'до-диез');
    expect(foundationScript('L01-07')!.transfer!.right, 'ре-бемоль');
    expect(letterForSyllable(SolfegeNotes.naturalNames[6]), 'B');

    final keyboard = Level0Plan.fromLesson(catalog.lesson('L01-01'));
    for (final step in keyboard.steps
        .where((step) => step.body.startsWith('Найти клавишу:'))) {
      expect(step.options[step.correctIndex], step.body.split(': ').last);
    }
  });
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(
      jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
