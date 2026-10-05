import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/theory/screens/theory_home_screen.dart';

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

  testWidgets('finishing a theory lesson writes the same progress book',
      (tester) async {
    final store = MemoryProgressStore(
        clock: FixedClock(DateTime.utc(2026, 10, 5)),
        rules: catalog.config.masteryRules);
    final lesson = catalog.lesson('L00-02');
    await tester.pumpWidget(
      MaterialApp(
        home: TheoryHomeScreen(
          catalog: catalog,
          progress: store,
          isMastered: (_) => true,
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Выше и ниже'), 400);
    await tester.tap(find.text('Выше и ниже'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('выше'));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('так же'));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('Тренировать'));

    final snapshot = store.snapshot(lesson.primaryCompetency);
    expect(store.book.attempts, hasLength(2));
    expect(store.book.attempts.every((attempt) => attempt.isCorrect), isTrue);
    expect(
        store.book.attempts.every(
            (attempt) => attempt.competencyId == lesson.primaryCompetency),
        isTrue);
    expect(snapshot.status, CompetencyStatus.practicing);
    expect(snapshot.status, isNot(CompetencyStatus.mastered));
    expect(snapshot.status, isNot(CompetencyStatus.provisionallyPassed));
  });

  testWidgets('a wrong lesson answer is stored and does not grant mastered',
      (tester) async {
    final store = MemoryProgressStore(
        clock: FixedClock(DateTime.utc(2026, 10, 5)),
        rules: catalog.config.masteryRules);
    final lesson = catalog.lesson('L00-02');
    await tester.pumpWidget(
      MaterialApp(
        home: TheoryHomeScreen(
            catalog: catalog, progress: store, isMastered: (_) => true),
      ),
    );
    await tester.scrollUntilVisible(find.text('Выше и ниже'), 400);
    await tester.tap(find.text('Выше и ниже'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('ниже'));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('выше'));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('Тренировать'));

    expect(store.book.attempts, hasLength(2));
    expect(store.book.attempts.every((attempt) => !attempt.isCorrect), isTrue);
    expect(
        store.book.attempts.every((attempt) => attempt.errorTag == lesson.id),
        isTrue);
    expect(store.snapshot(lesson.primaryCompetency).status,
        isNot(CompetencyStatus.mastered));
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(
      jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
