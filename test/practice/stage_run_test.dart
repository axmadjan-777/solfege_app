import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/practice/progress/practice_attempt.dart';
import 'package:solfege_app/features/practice/progress/stage_progress.dart';
import 'package:solfege_app/features/practice/screens/practice_map_screen.dart';
import 'package:solfege_app/features/practice/screens/stage_list_screen.dart';
import 'package:solfege_app/features/practice/screens/practice_round_screen.dart';
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

  testWidgets(
      'stage list opens independent delayed review and keeps stage pass separate',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 11, 5, 9));
    final store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    final set = catalog.practiceSet('PR-01');
    final spec = set.stages.firstWhere((stage) => stage.stage == 2);
    for (final id in spec.competencyIds) {
      final plan = buildStageSession(set: set, stage: 2, seed: 1);
      final task =
          plan.tasks.firstWhere((task) => task.competencyIds.contains(id));
      final profile = stageCompetencyPolicy(
          catalog: catalog, stage: spec, competencyId: id);
      for (var i = 0; i < profile.rules.immediateWindow; i++) {
        recordStageAnswer(
            store: store,
            catalog: catalog,
            set: set,
            stage: 2,
            task: task,
            correct: true,
            sessionId: 'training-$id-$i',
            now: clock.now());
      }
    }
    store.markStagePassed('PR-01', 1);
    store.markStagePassed('PR-01', 2);
    const id = 'ear.degree.major.1';
    const reviewKey = Key('stage-review-PR-01-2-ear.degree.major.1');
    Widget screen() => MaterialApp(
            home: StageListScreen(
          key: UniqueKey(),
          set: set,
          player: FakePracticeAudioPlayer(),
          catalog: catalog,
          progress: store,
          clock: clock,
        ));
    await tester.pumpWidget(screen());
    final early = tester.widget<TextButton>(find.byKey(reviewKey));
    expect(early.onPressed, isNull);
    expect(find.textContaining('Холодная проверка через'), findsWidgets);
    clock.advance(Duration(
        hours: stageCompetencyPolicy(
                catalog: catalog, stage: spec, competencyId: id)
            .policy
            .firstDelayRangeHours
            .$1));
    await tester.pumpWidget(screen());
    await _tap(tester, find.byKey(reviewKey));
    await tester.pumpAndSettle();
    final run = tester.widget<StageRunScreen>(find.byType(StageRunScreen));
    final review = buildStageReviewSession(
        catalog: catalog, set: set, stage: 2, competencyId: id, seed: run.seed);
    for (var i = 0; i < review.tasks.length; i++) {
      await _tap(tester, find.text(review.tasks[i].answer));
      await _tap(
          tester, find.text(i + 1 == review.tasks.length ? 'Итог' : 'Дальше'));
    }
    expect(find.text('Навык освоен'), findsOneWidget);
    expect(store.snapshot(id).status, CompetencyStatus.mastered);
    expect(store.snapshot('ear.degree.major.5').status,
        CompetencyStatus.provisionallyPassed);
    expect(store.book.passedStages['PR-01'], [1, 2]);
    expect(store.book.competencies, isNot(contains('sca.tonic')));
  });

  testWidgets('direct early cold-review entry cannot grade or write an answer',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 11, 5));
    final store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    final set = catalog.practiceSet('PR-01');
    final spec = set.stages.firstWhere((stage) => stage.stage == 4);
    const id = 'ear.degree.major.2';
    final task = buildStageSession(set: set, stage: 4, seed: 2)
        .tasks
        .firstWhere((task) => task.competencyIds.contains(id));
    final profile =
        stageCompetencyPolicy(catalog: catalog, stage: spec, competencyId: id);
    for (var i = 0; i < profile.rules.immediateWindow; i++) {
      recordStageAnswer(
          store: store,
          catalog: catalog,
          set: set,
          stage: 4,
          task: task,
          correct: true,
          sessionId: 'learn-$i',
          now: clock.now());
    }
    final before = store.book.attempts.length;
    await tester.pumpWidget(MaterialApp(
        home: StageRunScreen(
      set: set,
      stage: 4,
      player: FakePracticeAudioPlayer(),
      catalog: catalog,
      clock: clock,
      seed: 1,
      progress: store,
      reviewCompetencyId: id,
    )));
    expect(find.textContaining('Холодная проверка через'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(store.book.attempts, hasLength(before));
    expect(store.snapshot(id).status, CompetencyStatus.provisionallyPassed);
  });

  testWidgets(
      'rhythm stages without an answer judge show an explanation and no bypass',
      (tester) async {
    final store = MemoryProgressStore(
        clock: FixedClock(DateTime.utc(2026, 11, 5)),
        rules: catalog.config.masteryRules);
    await tester.pumpWidget(MaterialApp(
        home: StageListScreen(
      set: catalog.practiceSet('PR-13'),
      player: FakePracticeAudioPlayer(),
      catalog: catalog,
      progress: store,
    )));
    expect(find.textContaining('оценка ритма'), findsWidgets);
    expect(find.byKey(const Key('practice-review')), findsNothing);
    final tile =
        tester.widget<ListTile>(find.byKey(const Key('stage-PR-13-1')));
    expect(tile.enabled, isFalse);
    expect(tile.onTap, isNull);
    expect(store.book.attempts, isEmpty);
  });

  testWidgets('legacy minor practice still opens its existing trainer', (
    tester,
  ) async {
    final store = MemoryProgressStore(
      clock: FixedClock(DateTime.utc(2026, 10, 5, 9)),
      rules: catalog.config.masteryRules,
    );
    final screen = openPractice(
      setId: 'PR-02',
      player: FakePracticeAudioPlayer(),
      catalog: catalog,
      progress: store,
      clock: store.clock,
    );
    expect(screen, isA<PracticeRoundScreen>());
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();
    expect(find.text('Тоника минора'), findsOneWidget);
    expect(find.byType(StageListScreen), findsNothing);
  });

  testWidgets(
    'map keeps the delayed-review route to mastered alongside stages',
    (tester) async {
      final clock = FixedClock(DateTime.utc(2026, 10, 5, 9));
      final store = MemoryProgressStore(
        clock: clock,
        rules: catalog.config.masteryRules,
      );
      for (var i = 0; i < catalog.config.masteryRules.immediateWindow; i++) {
        recordPracticeAnswer(
          store: store,
          catalog: catalog,
          setId: 'PR-03',
          correct: true,
        );
      }
      final competency = competencyOf(catalog.practiceSet('PR-03'));
      expect(
        store.snapshot(competency).status,
        CompetencyStatus.provisionallyPassed,
      );
      clock.advance(const Duration(hours: 20));
      await tester.pumpWidget(
        MaterialApp(
          home: PracticeMapScreen(
            catalog: catalog,
            player: FakePracticeAudioPlayer(),
            progress: store,
            clock: clock,
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('Интервалы на слух'), 400);
      await tester.tap(find.text('Интервалы на слух'));
      await tester.pumpAndSettle();
      expect(find.text('Шире или уже'), findsOneWidget);
      await tester.tap(find.byKey(const Key('practice-review')));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('м3'));
      await _tap(tester, find.text('Холодная проверка'));
      for (var i = 0;
          i < catalog.competency('ear.interval.m3_M3').coldReviewMinItems;
          i++) {
        await _tap(tester, find.text('м3'));
        if (i + 1 <
            catalog.competency('ear.interval.m3_M3').coldReviewMinItems) {
          await _tap(tester, find.text('Следующее'));
        }
      }
      expect(store.snapshot(competency).status, CompetencyStatus.mastered);
      expect(find.text('Освоено'), findsWidgets);
    },
  );

  testWidgets('passing stage 1 opens stage 2 and does not master the skill', (
    tester,
  ) async {
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
    await tester.pumpWidget(
      MaterialApp(
        home: StageListScreen(
          set: set,
          player: FakePracticeAudioPlayer(),
          catalog: catalog,
          progress: store,
          clock: store.clock,
        ),
      ),
    );
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
    expect(
      store.snapshot('sca.tonic').status,
      isNot(CompetencyStatus.mastered),
    );
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

  testWidgets('a delayed pulse replay resets partial taps and the cue clock',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 11, 5));
    final set = catalog.practiceSet('PR-09');
    final plan = buildStageSession(set: set, stage: 1, seed: 1);
    final task = plan.tasks.first;
    final store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    await tester.pumpWidget(MaterialApp(
        home: StageRunScreen(
      set: set,
      stage: 1,
      player: FakePracticeAudioPlayer(),
      catalog: catalog,
      clock: clock,
      seed: 1,
      progress: store,
    )));
    await tester.pump();
    clock.advance(Duration(milliseconds: task.gapMs));
    await _tap(tester, find.textContaining('Доля'));
    expect(find.text('Доля (1 из ${task.beats})'), findsOneWidget);

    clock.advance(const Duration(seconds: 10));
    await _tap(tester, find.text('Ещё раз (3)'));
    expect(find.text('Доля (0 из ${task.beats})'), findsOneWidget);
    for (var i = 0; i < task.beats; i++) {
      clock.advance(Duration(milliseconds: task.gapMs));
      await _tap(tester, find.textContaining('Доля'));
    }
    expect(find.text('Верно'), findsOneWidget);
    expect(store.book.attempts.single.isCorrect, isTrue);
    expect(store.book.attempts.single.responseMs, task.gapMs * task.beats);
  });

  testWidgets(
      'speed stage rejects slow correct answers and stores real response durations',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> tapVisible(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump();
      expect(finder.hitTestable(), findsOneWidget);
      await tester.tap(finder.hitTestable());
      await tester.pump();
    }

    final clock = FixedClock(DateTime.utc(2026, 11, 5));
    final store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    final set = catalog.practiceSet('PR-08');
    final plan = buildStageSession(set: set, stage: 3, seed: 1);
    Widget screen(Key key) => MaterialApp(
            home: StageRunScreen(
          key: key,
          set: set,
          stage: 3,
          player: FakePracticeAudioPlayer(),
          catalog: catalog,
          clock: clock,
          seed: 1,
          progress: store,
        ));
    await tester.pumpWidget(screen(const Key('slow-run')));
    await tester.pump();
    for (var i = 0; i < plan.tasks.length; i++) {
      clock.advance(const Duration(seconds: 3));
      await tapVisible(find.text(plan.tasks[i].answer));
      await tapVisible(
          find.text(i + 1 == plan.tasks.length ? 'Итог' : 'Дальше'));
    }
    expect(find.text('Пока не сдано'), findsOneWidget);
    expect(find.textContaining('Медиана ответа: 3000 мс'), findsOneWidget);
    expect(store.book.passedStages['PR-08'], isNull);
    expect(store.book.attempts.every((attempt) => attempt.responseMs == 3000),
        isTrue);

    await tester.pumpWidget(screen(const Key('backward-clock-run')));
    await tester.pump();
    for (var i = 0; i < plan.tasks.length; i++) {
      clock.advance(const Duration(seconds: -1));
      await tapVisible(find.text(plan.tasks[i].answer));
      await tapVisible(
          find.text(i + 1 == plan.tasks.length ? 'Итог' : 'Дальше'));
    }
    expect(find.text('Пока не сдано'), findsOneWidget);
    expect(find.text('Системные часы изменились. Повторите скоростной раунд.'),
        findsOneWidget);
    expect(store.book.passedStages['PR-08'], isNull);
    expect(
        store.book.attempts
            .skip(plan.tasks.length)
            .every((attempt) => attempt.responseMs == 0),
        isTrue);

    await tester.pumpWidget(screen(const Key('fast-run')));
    await tester.pump();
    for (var i = 0; i < plan.tasks.length; i++) {
      clock.advance(const Duration(seconds: 1));
      await tapVisible(find.text(plan.tasks[i].answer));
      await tapVisible(
          find.text(i + 1 == plan.tasks.length ? 'Итог' : 'Дальше'));
    }
    expect(find.text('Сдано'), findsOneWidget);
    expect(find.textContaining('Медиана ответа: 1000 мс'), findsOneWidget);
    expect(store.book.passedStages['PR-08'], [3]);
    expect(
        store.book.attempts
            .skip(plan.tasks.length * 2)
            .every((attempt) => attempt.responseMs == 1000),
        isTrue);
    final restored = ProgressBook.fromJson(
        jsonDecode(jsonEncode(store.book.toJson())) as Map<String, dynamic>);
    expect(restored.attempts.first.responseMs, 3000);
    expect(restored.attempts.last.responseMs, 1000);
  });

  testWidgets('four taps on the grid count as the pulse', (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 9));
    final set = catalog.practiceSet('PR-09');
    final seed = stageSessionSeed('PR-09', 1, 0);
    final plan = buildStageSession(set: set, stage: 1, seed: seed);
    await tester.pumpWidget(
      MaterialApp(
        home: StageRunScreen(
          set: set,
          stage: 1,
          player: FakePracticeAudioPlayer(),
          catalog: catalog,
          clock: clock,
          seed: seed,
        ),
      ),
    );
    await tester.pump();
    final task = plan.tasks.first;
    for (var i = 0; i < task.beats; i++) {
      clock.advance(Duration(milliseconds: task.gapMs));
      await _tap(tester, find.textContaining('Доля'));
    }
    expect(find.text('Верно'), findsOneWidget);
    expect(find.text('Ноты скрыты'), findsOneWidget);
  });

  testWidgets(
    'building a fifth records the answer and keeps the notes hidden',
    (tester) async {
      final store = MemoryProgressStore(
        clock: FixedClock(DateTime.utc(2026, 10, 5, 9)),
        rules: catalog.config.masteryRules,
      );
      final set = catalog.practiceSet('PR-04');
      final seed = stageSessionSeed('PR-04', 2, 0);
      final plan = buildStageSession(set: set, stage: 2, seed: seed);
      await tester.pumpWidget(
        MaterialApp(
          home: StageRunScreen(
            set: set,
            stage: 2,
            player: FakePracticeAudioPlayer(),
            catalog: catalog,
            progress: store,
            clock: store.clock,
            seed: seed,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Ноты скрыты'), findsOneWidget);
      await _tap(tester, find.text(plan.tasks.first.answer));
      expect(find.text('Верно'), findsOneWidget);
      expect(store.book.attempts.single.isCorrect, isTrue);
      expect(
        store.snapshot('int.number').status,
        isNot(CompetencyStatus.mastered),
      );
    },
  );
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
