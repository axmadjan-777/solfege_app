import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/practice_attempt.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/practice/screens/practice_followup.dart';
import 'package:solfege_app/features/practice/screens/practice_map_screen.dart';

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

  testWidgets('a correct interval is stored as practicing and not mastered',
      (tester) async {
    final store = _store();
    final player = FakePracticeAudioPlayer();
    await tester.pumpWidget(
      MaterialApp(
          home: PracticeMapScreen(
              catalog: catalog, player: player, progress: store)),
    );
    await tester.scrollUntilVisible(find.text('Интервалы на слух'), 400);
    await tester.tap(find.text('Интервалы на слух'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('м3'));
    await tester.pump();

    final competency = competencyOf(
        catalog.practiceSets.firstWhere((set) => set.id == 'PR-03'));
    expect(competency, 'ear.interval.m3_M3');
    expect(store.book.attempts.single.isCorrect, isTrue);
    expect(store.snapshot(competency).status, CompetencyStatus.practicing);
    expect(store.snapshot(competency).status, isNot(CompetencyStatus.mastered));
  });

  testWidgets('a wrong interval and a sung report stay below mastered',
      (tester) async {
    final store = _store();
    final player = FakePracticeAudioPlayer();
    await tester.pumpWidget(
      MaterialApp(
        home: practiceSetScreen(
            setId: 'PR-03', player: player, catalog: catalog, progress: store),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('б3'));
    await tester.pump();
    expect(store.book.attempts.single.isCorrect, isFalse);
    expect(store.book.attempts.single.errorTag, 'PR-03');

    await tester.pumpWidget(
      MaterialApp(
        home: practiceSetScreen(
            setId: 'PR-14', player: player, catalog: catalog, progress: store),
      ),
    );
    await tester.tap(find.text('Я спел'));
    await tester.pump();
    final sing = competencyOf(
        catalog.practiceSets.firstWhere((set) => set.id == 'PR-14'));
    expect(store.snapshot(sing).status, isNot(CompetencyStatus.mastered));
    expect(store.book.attempts, hasLength(2));
  });
}

MemoryProgressStore _store() {
  final catalog = CurriculumCatalog.fromDecoded(
    levels: _read('levels.json'),
    sourceMap: _read('source-map.json'),
    audioManifest: _read('audio-manifest.json'),
    exercises: _read('exercises.json'),
    competencies: _read('competencies.json'),
    lessons: _read('lessons.json'),
  );
  return MemoryProgressStore(
      clock: FixedClock(DateTime.utc(2026, 10, 5)),
      rules: catalog.config.masteryRules);
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(
      jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
