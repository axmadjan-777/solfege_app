import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/screens/practice_map_screen.dart';
import 'package:solfege_app/features/practice/trainers/assessment.dart';

void main() {
  late AssessmentRules rules;
  late CurriculumCatalog catalog;

  setUpAll(() {
    catalog = _catalog();
    rules = AssessmentRules.fromConfig(catalog.config.raw);
  });

  test('the exam needs 0.85 overall and 0.75 in every block, taken from config', () {
    expect(rules.examOverall, 0.85);
    expect(rules.examPerBlock, 0.75);
    expect(rules.examPassed(overall: 0.85, blocks: const [0.75, 0.75, 0.9]), isTrue);
    expect(rules.examPassed(overall: 0.9, blocks: const [0.9, 0.74, 0.9]), isFalse);
    expect(rules.examPassed(overall: 0.84, blocks: const [0.9, 0.9, 0.9]), isFalse);
  });

  test('diagnostic never grants mastered, and a broken streak keeps the competency', () {
    expect(rules.diagnosticGrantsMastered, isFalse);
    expect(rules.diagnosticStatus(), isNot(CompetencyStatus.mastered));
    expect(rules.diagnosticAxes, ['чтение', 'ритм', 'слух высоты', 'теория']);
    expect(rules.afterBrokenStreak(CompetencyStatus.mastered), CompetencyStatus.mastered);
  });

  test('skip uses 4 to 6 items, two representations, transfer, and 0.9', () {
    expect(rules.skipMinItems, 4);
    expect(rules.skipMaxItems, 6);
    expect(
      rules.skipPassed(items: 5, representations: 2, transfer: true, accuracy: 0.9),
      isTrue,
    );
    expect(
      rules.skipPassed(items: 5, representations: 1, transfer: true, accuracy: 0.95),
      isFalse,
    );
    expect(rules.checkpointItems, 6);
    expect(rules.checkpointHints, 1);
    expect(rules.checkpointPassed(0.8), isTrue);
    expect(rules.checkpointPassed(0.79), isFalse);
  });

  testWidgets('the note-reading card opens diagnostic without granting mastered', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PracticeMapScreen(catalog: catalog)));
    await tester.scrollUntilVisible(find.text('Чтение нот'), 500);
    await tester.tap(
      find.descendant(of: find.byKey(const Key('practice-PR-08')), matching: find.text('Диагностика')),
    );
    await tester.pumpAndSettle();

    expect(find.text('слух высоты'), findsOneWidget);
    expect(find.text('Завершить'), findsOneWidget);
    expect(rules.diagnosticStatus(), isNot(CompetencyStatus.mastered));
  });
}

CurriculumCatalog _catalog() {
  Map<String, dynamic> read(String name) {
    return Map<String, dynamic>.from(jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
  }

  return CurriculumCatalog.fromDecoded(
    levels: read('levels.json'),
    sourceMap: read('source-map.json'),
    audioManifest: read('audio-manifest.json'),
    exercises: read('exercises.json'),
    competencies: read('competencies.json'),
    lessons: read('lessons.json'),
  );
}
