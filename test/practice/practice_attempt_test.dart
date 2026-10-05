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
import 'package:solfege_app/features/practice/screens/practice_round_screen.dart';

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

  testWidgets(
      'twelve correct answers stay provisional until a later cold review',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5));
    final store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    final player = FakePracticeAudioPlayer();
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeRoundScreen(
          setId: 'PR-03',
          player: player,
          catalog: catalog,
          progress: store,
          clock: clock,
        ),
      ),
    );

    for (var i = 0; i < 12; i++) {
      await tester.pump();
      await tester.tap(find.text('м3'));
      await tester.pump();
      if (i < 11) {
        await tester.tap(find.text('Следующее'));
        await tester.pump();
      }
    }

    final competency = competencyOf(
        catalog.practiceSets.firstWhere((set) => set.id == 'PR-03'));
    expect(find.text('Предварительно сдано'), findsOneWidget);
    expect(store.snapshot(competency).status,
        CompetencyStatus.provisionallyPassed);

    await tester.tap(find.text('Холодная проверка'));
    await tester.pump();
    expect(find.text('Рано'), findsOneWidget);
    expect(store.snapshot(competency).status,
        CompetencyStatus.provisionallyPassed);

    clock.advance(const Duration(hours: 20));
    await tester.tap(find.text('Холодная проверка'));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await _answer(tester, 'м3');
      if (i < 3) {
        await tester.tap(find.text('Следующее'));
        await tester.pump();
      }
    }
    expect(find.text('Освоено'), findsWidgets);
    expect(store.snapshot(competency).status, CompetencyStatus.mastered);
  });

  testWidgets('a miss on the cold review asks to practice again',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5));
    final store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    for (var i = 0; i < 12; i++) {
      recordPracticeAnswer(
          store: store, catalog: catalog, setId: 'PR-03', correct: true);
    }
    clock.advance(const Duration(hours: 20));
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeRoundScreen(
          setId: 'PR-03',
          player: FakePracticeAudioPlayer(),
          catalog: catalog,
          progress: store,
          clock: clock,
        ),
      ),
    );
    await _answer(tester, 'м3');
    await tester.tap(find.text('Холодная проверка'));
    await tester.pump();
    for (final label in ['м3', 'м3', 'м3', 'б3']) {
      await _answer(tester, label);
      if (label != 'б3') {
        await tester.tap(find.text('Следующее'));
        await tester.pump();
      }
    }

    final competency = competencyOf(
        catalog.practiceSets.firstWhere((set) => set.id == 'PR-03'));
    expect(find.text('Нужно повторить'), findsOneWidget);
    expect(store.snapshot(competency).status, CompetencyStatus.needsReview);
    expect(store.snapshot(competency).provisionalAt, isNull);
    expect(find.text('Освоено'), findsNothing);
  });

  test('four of the last six correct answers stay provisionally passed', () {
    final store = _store();
    for (var i = 0; i < 12; i++) {
      recordPracticeAnswer(
          store: store, catalog: catalog, setId: 'PR-03', correct: true);
    }
    for (final correct in [true, true, true, true, false, false]) {
      recordPracticeAnswer(
          store: store, catalog: catalog, setId: 'PR-03', correct: correct);
    }

    final competency = competencyOf(
        catalog.practiceSets.firstWhere((set) => set.id == 'PR-03'));
    expect(store.snapshot(competency).status,
        CompetencyStatus.provisionallyPassed);
  });

  testWidgets('four misses in the last six answers ask for review',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5));
    final store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    final player = FakePracticeAudioPlayer();
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeRoundScreen(
          setId: 'PR-03',
          player: player,
          catalog: catalog,
          progress: store,
          clock: clock,
        ),
      ),
    );

    for (var i = 0; i < 12; i++) {
      await _answer(tester, 'м3');
      if (i < 11) {
        await tester.tap(find.text('Следующее'));
        await tester.pump();
      }
    }
    for (final label in ['м3', 'м3', 'б3', 'б3', 'б3', 'б3']) {
      await tester.tap(find.text('Следующее'));
      await tester.pump();
      await _answer(tester, label);
    }

    final competency = competencyOf(
        catalog.practiceSets.firstWhere((set) => set.id == 'PR-03'));
    expect(find.text('Нужно повторить'), findsOneWidget);
    expect(store.snapshot(competency).status, CompetencyStatus.needsReview);
    expect(find.text('Холодная проверка'), findsNothing);
  });

  test('eleven correct answers after the misses restore provisional status',
      () {
    final store = _store();
    _slip(store, catalog);
    final competency = competencyOf(
        catalog.practiceSets.firstWhere((set) => set.id == 'PR-03'));
    final marked = store.snapshot(competency).provisionalAt;
    expect(store.snapshot(competency).status, CompetencyStatus.needsReview);

    for (var i = 0; i < 10; i++) {
      recordPracticeAnswer(
          store: store, catalog: catalog, setId: 'PR-03', correct: true);
    }
    expect(store.snapshot(competency).status, CompetencyStatus.needsReview);

    recordPracticeAnswer(
        store: store, catalog: catalog, setId: 'PR-03', correct: true);
    expect(store.snapshot(competency).status,
        CompetencyStatus.provisionallyPassed);
    expect(store.snapshot(competency).provisionalAt, marked);
    expect(store.snapshot(competency).status, isNot(CompetencyStatus.mastered));
  });

  testWidgets(
      'the round screen returns to provisional after the window recovers',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5));
    final store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    _slip(store, catalog);
    final player = FakePracticeAudioPlayer();
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeRoundScreen(
          setId: 'PR-03',
          player: player,
          catalog: catalog,
          progress: store,
          clock: clock,
        ),
      ),
    );

    for (var i = 0; i < 11; i++) {
      await _answer(tester, 'м3');
      if (i == 9) expect(find.text('Нужно повторить'), findsOneWidget);
      if (i < 10) {
        await tester.tap(find.text('Следующее'));
        await tester.pump();
      }
    }

    expect(find.text('Предварительно сдано'), findsOneWidget);
    expect(find.text('Холодная проверка'), findsOneWidget);
    final competency = competencyOf(
        catalog.practiceSets.firstWhere((set) => set.id == 'PR-03'));
    expect(store.snapshot(competency).status,
        CompetencyStatus.provisionallyPassed);
    await tester.tap(find.text('Холодная проверка'));
    await tester.pump();
    expect(find.text('Рано'), findsOneWidget);
    expect(store.snapshot(competency).status, isNot(CompetencyStatus.mastered));
  });
}

void _slip(MemoryProgressStore store, CurriculumCatalog catalog) {
  for (var i = 0; i < 12; i++) {
    recordPracticeAnswer(
        store: store, catalog: catalog, setId: 'PR-03', correct: true);
  }
  for (final correct in [true, true, false, false, false, false]) {
    recordPracticeAnswer(
        store: store, catalog: catalog, setId: 'PR-03', correct: correct);
  }
}

Future<void> _answer(WidgetTester tester, String label) async {
  await tester.pump();
  await tester.tap(find.text(label));
  await tester.pump();
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
