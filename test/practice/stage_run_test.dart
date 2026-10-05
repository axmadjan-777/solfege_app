import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/practice/screens/stage_list_screen.dart';
import 'package:solfege_app/features/practice/screens/stage_run_screen.dart';
import 'package:solfege_app/features/practice/trainers/stage_catalog.dart';

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

  testWidgets('passing stage 1 opens stage 2 and does not master the skill', (tester) async {
    final store = MemoryProgressStore(
      clock: FixedClock(DateTime.utc(2026, 10, 5, 9)),
      rules: catalog.config.masteryRules,
    );
    final set = catalog.practiceSet('PR-01');
    final plan = buildStageSession(
      set: set,
      stage: 1,
      seed: stageSessionSeed('PR-01', 1, 0),
    );
    await tester.pumpWidget(MaterialApp(
      home: StageListScreen(
        set: set,
        player: FakePracticeAudioPlayer(),
        catalog: catalog,
        progress: store,
        clock: store.clock,
      ),
    ));
    expect(
      find.descendant(
        of: find.byKey(const Key('stage-PR-01-2')),
        matching: find.text('Закрыто'),
      ),
      findsOneWidget,
    );
    expect(find.text('Скоро'), findsNothing);

    await tester.tap(find.text('Установление тоники: закончено или нет'));
    await tester.pumpAndSettle();
    expect(find.text('Ноты скрыты'), findsOneWidget);

    for (var i = 0; i < plan.tasks.length; i++) {
      await _tap(tester, find.text(plan.tasks[i].answer));
      final last = i + 1 == plan.tasks.length;
      await _tap(tester, find.text(last ? 'Итог' : 'Дальше'));
    }

    expect(find.text('Сдано'), findsOneWidget);
    expect(store.snapshot('sca.tonic').status, isNot(CompetencyStatus.mastered));
    expect(store.book.passedStages['PR-01'], [1]);
    await _tap(tester, find.text('К этапам'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('stage-PR-01-2')),
        matching: find.text('Открыто'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('four taps on the grid count as the pulse', (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 9));
    final set = catalog.practiceSet('PR-09');
    final seed = stageSessionSeed('PR-09', 1, 0);
    final plan = buildStageSession(set: set, stage: 1, seed: seed);
    await tester.pumpWidget(MaterialApp(
      home: StageRunScreen(
        set: set,
        stage: 1,
        player: FakePracticeAudioPlayer(),
        catalog: catalog,
        clock: clock,
        seed: seed,
      ),
    ));
    await tester.pump();
    final task = plan.tasks.first;
    for (var i = 0; i < task.beats; i++) {
      clock.advance(Duration(milliseconds: task.gapMs));
      await _tap(tester, find.textContaining('Доля'));
    }
    expect(find.text('Верно'), findsOneWidget);
    expect(find.text('Ноты скрыты'), findsOneWidget);
  });

  testWidgets('building a fifth records the answer and keeps the notes hidden', (tester) async {
    final store = MemoryProgressStore(
      clock: FixedClock(DateTime.utc(2026, 10, 5, 9)),
      rules: catalog.config.masteryRules,
    );
    final set = catalog.practiceSet('PR-04');
    final seed = stageSessionSeed('PR-04', 2, 0);
    final plan = buildStageSession(set: set, stage: 2, seed: seed);
    await tester.pumpWidget(MaterialApp(
      home: StageRunScreen(
        set: set,
        stage: 2,
        player: FakePracticeAudioPlayer(),
        catalog: catalog,
        progress: store,
        clock: store.clock,
        seed: seed,
      ),
    ));
    await tester.pump();
    expect(find.text('Ноты скрыты'), findsOneWidget);
    await _tap(tester, find.text(plan.tasks.first.answer));
    expect(find.text('Верно'), findsOneWidget);
    expect(store.book.attempts.single.isCorrect, isTrue);
    expect(store.snapshot('int.number').status, isNot(CompetencyStatus.mastered));
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
    jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map,
  );
}
