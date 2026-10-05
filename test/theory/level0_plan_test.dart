import 'dart:convert';
import 'dart:io';

import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/progress_rules.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
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

  test('L00-01 uses the card text, the sound pool and does not grant mastered', () {
    final lesson = catalog.lesson('L00-01');
    final plan = Level0Plan.fromLesson(lesson);

    expect(plan.steps.first.body, lesson.plainExplanation);
    expect(plan.steps.where((step) => step.kind == 'guided'), hasLength(lesson.learningItems));
    expect(plan.steps.where((step) => step.kind == 'check'), hasLength(lesson.checkItems));
    expect(plan.steps.last.body, lesson.finalTask);
    expect(plan.steps.last.feedbackCorrect, lesson.feedbackCorrect);
    expect(plan.steps.map((step) => step.body).join(' '), contains('шейкер'));
    expect(plan.steps.map((step) => step.body).join(' '), contains('фортепиано'));
    expect(statusAfterLesson(), isNot(CompetencyStatus.mastered));
  });

  test('L00-06 is a pulse lesson on T09 and stays at or below 100 BPM', () {
    final lesson = catalog.lesson('L00-06');
    final plan = Level0Plan.fromLesson(lesson);
    final pulse = plan.steps.where((step) => step.templateId == 'T09').toList();

    expect(pulse, isNotEmpty);
    expect(pulse.every((step) => step.tapsRequired == 4), isTrue);
    expect(pulse.first.body, contains('70 BPM'));
    expect(pulse.any((step) => step.body.contains('100 BPM')), isTrue);
    expect(pulse.any((step) => step.body.contains('101')), isFalse);
  });

  test('L00-02 stays closed until the previous competency is mastered', () {
    final lesson = catalog.lesson('L00-02');

    expect(isLessonOpen(lesson: lesson, catalog: catalog, isMastered: (_) => false), isFalse);
    expect(
      isLessonOpen(lesson: lesson, catalog: catalog, isMastered: (id) => id == 'snd.tone_vs_noise'),
      isTrue,
    );
    expect(
      isLessonOpen(lesson: catalog.lesson('L00-01'), catalog: catalog, isMastered: (_) => false),
      isTrue,
    );
  });

  test('recording a finished level 0 lesson does not set mastered', () {
    final clock = FixedClock(DateTime.utc(2026, 10, 5));
    final store = MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    final plan = Level0Plan.fromLesson(catalog.lesson('L00-01'));
    final answers = plan.steps.where((step) => !step.isExplanation).length;

    store.recordSession(
      SessionDraft(
        competencyId: plan.primaryCompetency,
        sessionId: 'L00-01',
        correct: List<bool>.filled(answers, true),
        policy: catalog.config.policy('RP-aural'),
        tonality: 'C',
      ),
    );

    expect(store.snapshot(plan.primaryCompetency).status, isNot(CompetencyStatus.mastered));
  });
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
