import 'dart:convert';
import 'dart:io';

import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/progress/progress_rules.dart';
import 'package:solfege_app/features/scales/utils/solfege_notes.dart';
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

  test('syllable names come from SolfegeNotes and si is B', () {
    expect(SolfegeNotes.naturalNames, ['до', 'ре', 'ми', 'фа', 'соль', 'ля', 'си']);
    expect(letterForSyllable('си'), 'B');
    expect(letterForSyllable('до'), 'C');
    expect(() => letterForSyllable('H'), throwsArgumentError);
  });

  test('L01-01 stays closed until the keyboard lesson competency is mastered', () {
    final lesson = catalog.lesson('L01-01');
    final plan = Level0Plan.fromLesson(lesson);

    expect(plan.steps.first.body, lesson.plainExplanation);
    expect(plan.steps.any((step) => step.options.contains('до')), isTrue);
    expect(isLessonOpen(lesson: lesson, catalog: catalog, isMastered: (_) => false), isFalse);
    expect(
      isLessonOpen(lesson: lesson, catalog: catalog, isMastered: (id) => id == 'kbd.layout_groups'),
      isTrue,
    );
  });
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
