import 'dart:convert';
import 'dart:io';

import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/trainers/note_reading.dart';
import 'package:solfege_app/features/scales/utils/treble_staff_layout.dart';
import 'package:solfege_app/features/theory/level0/early_level_plan.dart';
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

  test('levels 2–4 answer from rhythm, staff and major rules', () {
    final lessons = catalog.lessons
        .where((lesson) => earlyLevelSteps(lesson) != null)
        .toList();
    expect(lessons, hasLength(24));
    for (final lesson in lessons) {
      final plan = Level0Plan.fromLesson(lesson);
      final script = earlyScript(lesson.id)!;
      expect(plan.steps, hasLength(3));
      expect(plan.steps.first.body, lesson.plainExplanation);
      expect(plan.steps[1].options[plan.steps[1].correctIndex],
          script.guided.right);
      expect(script.guided.right, isNot('ошибка'));
      expect(script.guided.right, isNot(script.guided.wrong));
      expect(plan.trainPracticeSetIds, lesson.practiceSetIds);
    }

    expect(TrebleStaffLayout.lineCount, 5);
    expect(NoteReading.stemUp(60), isTrue);
    expect(NoteReading.stemUp(71), isFalse);
    expect(earlyScript('L02-02')!.guided.right, '2/4');
    expect(earlyScript('L02-02')!.transfer!.right, '3/4');
    expect(earlyScript('L02-04')!.guided.right, 'половинная');
    expect(earlyScript('L02-05')!.guided.right, 'четверть');
    expect(earlyScript('L02-06')!.guided.right, 'как четверть');
    expect(earlyScript('L02-07')!.guided.right, 'полторы четверти');
    expect(earlyScript('L03-01')!.guided.right, '5');
    expect(earlyScript('L03-02')!.guided.right, 'соль');
    expect(earlyScript('L03-03')!.guided.right, 'до, соль, до');
    expect(earlyScript('L03-06')!.guided.right, 'вверх');
    expect(earlyScript('L03-07')!.guided.right, 'фа');
    expect(earlyScript('L03-09')!.guided.right, 'обоим ключам');
    expect(earlyScript('L04-01')!.guided.right, 'полутон');
    expect(earlyScript('L04-03')!.guided.right, 'ре-бемоль');
    expect(earlyScript('L04-05')!.guided.right,
        'тон–тон–полутон–тон–тон–тон–полутон');
    expect(earlyScript('L04-06')!.guided.right, 'без знаков');
    expect(earlyScript('L04-08')!.guided.right, 'I, III, V');
    expect(earlyScript('L04-10')!.guided.right, 'соль мажор');
    expect(earlyScript('L04-10')!.transfer!.right, 'фа мажор');
    expect(Level0Plan.fromLesson(catalog.lesson('L04-11')).trainPracticeSetIds,
        ['PR-01']);
    expect(
        Level0Plan.fromLesson(catalog.lesson('L02-08'))
            .steps
            .any((step) => step.options.contains('да')),
        isFalse);
  });
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(
      jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
