import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/content_integrity.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';

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

  test('catalog loads the entities the rest of the app addresses', () {
    expect(catalog.practiceSet('PR-01').title, 'Ступеневый диктант в одной тональности (мажор)');
    expect(catalog.competency('ear.degree.major.1').firstLessonId, 'L04-11');
    expect(catalog.lesson('L04-11').practiceSetIds, contains('PR-01'));
    expect(catalog.lesson('L00-01').manualContentNeeded, isTrue);
    expect(catalog.audioItem('AU-02').id, 'AU-02');
    expect(catalog.level('L00').lessonCount, 8);
    expect(catalog.config.masteryRules.immediateMinAccuracy, 0.85);
    expect(catalog.config.policy('RP-aural').intervalDays, [1, 2, 5, 10, 21]);
  });

  test('part 27 json checks pass with the single known warning', () {
    final findings = ContentIntegrity(catalog).run();

    expect(
      findings.errors.map((f) => '${f.check}: ${f.detail}').toList(),
      isEmpty,
    );
    expect(findings.warnings.map((f) => f.detail).toList(), ['ear.scale.major_minor']);
  });

  test('PR-01 hides notation on every stage and covers seven degrees', () {
    final stages = catalog.practiceSet('PR-01').stages;

    expect(stages, hasLength(12));
    expect(stages.every((stage) => stage.params['show_notation'] == false), isTrue);
    expect(
      stages.expand((stage) => stage.targetSet).toSet(),
      {1, 2, 3, 4, 5, 6, 7},
    );
  });
}

Map<String, dynamic> _read(String name) {
  final text = File('assets/curriculum/$name').readAsStringSync();
  return Map<String, dynamic>.from(jsonDecode(text) as Map);
}
