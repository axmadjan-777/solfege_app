import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/error_return.dart';
import 'package:solfege_app/features/practice/progress/practice_attempt.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/practice/screens/practice_followup.dart';
import 'package:solfege_app/features/practice/trainers/error_queue.dart';
import 'package:solfege_app/features/practice/trainers/daily_mix.dart';
import 'package:solfege_app/features/practice/screens/practice_map_screen.dart';
import 'package:solfege_app/features/theory/level0/level0_plan.dart';
import 'package:solfege_app/features/theory/screens/theory_home_screen.dart';

void main() {
  late CurriculumCatalog catalog;
  late FakePracticeAudioPlayer player;

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

  setUp(() => player = FakePracticeAudioPlayer());

  testWidgets('every practice set opens its own screen', (tester) async {
    const titles = {
      'PR-01': 'Ступеневый диктант',
      'PR-02': 'Тоника минора',
      'PR-03': 'Интервал',
      'PR-04': 'Терция и квинта',
      'PR-05': 'Мажор или минор',
      'PR-06': 'Большое или малое',
      'PR-07': 'Найди и исправь ошибку',
      'PR-08': 'Опоры и соседи (C4–G4)',
      'PR-09': 'Пульс',
      'PR-10': 'Ритмический диктант',
      'PR-11': 'Мелодический диктант',
      'PR-12': 'Каденция',
      'PR-13': '4 такта, только высота',
      'PR-14': 'Пение',
      'PR-15': 'Ежедневный микс',
      'PR-16': 'Работа над ошибками',
    };
    for (final entry in titles.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: practiceSetScreen(
              setId: entry.key, player: player, catalog: catalog),
        ),
      );
      await tester.pump();
      expect(find.text(entry.value), findsWidgets, reason: entry.key);
      if (entry.key == 'PR-12') {
        expect(find.text('V–I — автентическая'), findsOneWidget);
      }
      if (entry.key == 'PR-14') {
        expect(find.text('Спой тонику. Это самоотчёт'), findsOneWidget);
      }
    }
  });

  testWidgets('the practice map opens interval ear', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: PracticeMapScreen(catalog: catalog, player: player)));
    await tester.scrollUntilVisible(find.text('Интервалы на слух'), 400);
    await tester.tap(find.text('Интервалы на слух'));
    await tester.pumpAndSettle();
    expect(find.text('м3'), findsOneWidget);
    expect(find.text('б3'), findsOneWidget);
    await tester.tap(find.text('м3'));
    await tester.pump();
    expect(find.text('Верно'), findsOneWidget);
  });

  testWidgets('L02-05 trains the pulse after the lesson', (tester) async {
    final lesson = catalog.lesson('L02-05');
    final mastered = {
      for (final ref in lesson.prerequisites)
        if (ref.lessonId != null)
          catalog.lesson(ref.lessonId!).primaryCompetency,
    };
    await tester.pumpWidget(
      MaterialApp(
        home: TheoryHomeScreen(
          catalog: catalog,
          player: player,
          isMastered: mastered.contains,
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Восьмые и вязка'), 400);
    await tester.tap(find.text('Восьмые и вязка'));
    await tester.pumpAndSettle();

    final plan = Level0Plan.fromLesson(lesson);
    await _tap(tester, find.text('Дальше'));
    for (final step in plan.steps.where((step) => !step.isExplanation)) {
      await _tap(tester, find.text(step.options[step.correctIndex]));
      await _tap(tester, find.text('Дальше'));
    }
    await _tap(tester, find.text('Тренировать'));
    await tester.pumpAndSettle();
    expect(find.text('Пульс'), findsOneWidget);
    expect(find.text('Тапни вместе с кликом'), findsOneWidget);
  });

  testWidgets('an empty book does not invent trainers', (tester) async {
    final store = MemoryProgressStore(
      clock: FixedClock(DateTime.utc(2026, 10, 5, 8)),
      rules: catalog.config.masteryRules,
    );
    await tester.pumpWidget(_mix(catalog, player, store, store.clock));
    expect(find.text('Пока нет должных заданий.'), findsOneWidget);
    expect(find.text('Начать'), findsNothing);
    expect(find.text('м3'), findsNothing);
  });

  testWidgets('a mastered note is named once as easy', (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 8));
    final store = MemoryProgressStore(
      clock: clock,
      rules: catalog.config.masteryRules,
      book: const ProgressBook(
        userId: 'local',
        competencies: {
          'not.read_treble_c4_g4': CompetencySnapshot(
            status: CompetencyStatus.mastered,
            stability: Stability(),
            intervalStep: 0,
            dueAt: null,
            provisionalAt: null,
          ),
        },
        attempts: [],
      ),
    );
    await tester.pumpWidget(_mix(catalog, player, store, clock));
    expect(find.text('Лёгкое: 2'), findsOneWidget);
    expect(find.text('Легко: Чтение нот'), findsOneWidget);
    expect(find.textContaining('Сначала:'), findsNothing);
  });

  testWidgets('a due interval leads the recent pulse and records the answer',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 8));
    final store = MemoryProgressStore(
      clock: clock,
      rules: catalog.config.masteryRules,
    );
    recordPracticeAnswer(
      store: store,
      catalog: catalog,
      setId: 'PR-03',
      correct: true,
    );
    await tester.pumpWidget(_mix(catalog, player, store, clock));
    expect(find.text('Должное: 0'), findsOneWidget);
    expect(find.text('Недавнее: 2'), findsOneWidget);
    expect(find.textContaining('Сначала:'), findsNothing);
    expect(find.text('Недавно: Интервалы на слух'), findsOneWidget);

    clock.advance(const Duration(days: 1));
    recordPracticeAnswer(
      store: store,
      catalog: catalog,
      setId: 'PR-09',
      correct: true,
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpWidget(_mix(catalog, player, store, clock));
    expect(find.text('Должное: 8'), findsOneWidget);
    expect(find.text('Недавнее: 2'), findsOneWidget);
    expect(find.text('Сначала: Интервалы на слух'), findsOneWidget);
    expect(find.text('Недавно: Ритм: пульс, эхо и чтение'), findsOneWidget);
    await tester.tap(find.text('Начать'));
    await tester.pump();
    expect(find.text('м3'), findsOneWidget);
    expect(find.text('Пульс'), findsNothing);
    await tester.tap(find.text('м3'));
    await tester.pump();
    expect(find.text('Верно'), findsOneWidget);
    expect(store.book.attempts.last.errorTag, 'PR-03');
    expect(store.book.attempts.last.isCorrect, isTrue);
  });

  testWidgets('a miss is due the same day and a correct retry clears it',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 8));
    final store = MemoryProgressStore(
      clock: clock,
      rules: catalog.config.masteryRules,
    );
    recordPracticeAnswer(
      store: store,
      catalog: catalog,
      setId: 'PR-03',
      correct: false,
    );
    await tester.pumpWidget(_mix(catalog, player, store, clock));
    expect(find.text('Должное: 8'), findsOneWidget);
    expect(find.text('Недавнее: 0'), findsOneWidget);
    expect(find.text('Сначала: Интервалы на слух'), findsOneWidget);
    await tester.tap(find.text('Начать'));
    await tester.pump();
    expect(find.text('м3'), findsOneWidget);
    await tester.tap(find.text('м3'));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpWidget(_mix(catalog, player, store, clock));
    expect(find.text('Должное: 0'), findsOneWidget);
    expect(find.text('Недавнее: 2'), findsOneWidget);
  });

  testWidgets('an open lesson leads the mix and a perfect retry clears it',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 8));
    final store = MemoryProgressStore(
      clock: clock,
      rules: catalog.config.masteryRules,
    );
    final lesson = catalog.lesson('L00-02');
    recordLessonResult(
      store: store,
      catalog: catalog,
      lesson: lesson,
      correct: 0,
      total: 2,
    );
    await tester.pumpWidget(_mix(catalog, player, store, clock));
    expect(find.text('Должное: 8'), findsOneWidget);
    expect(find.text('Сначала: Выше и ниже'), findsOneWidget);
    await tester.tap(find.text('Начать'));
    await tester.pump();
    expect(find.text('Выше и ниже'), findsOneWidget);
    expect(find.text('Ми относительно до'), findsNothing);

    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('выше'));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('так же'));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('Тренировать'));
    expect(ErrorQueue.openTags(store.book.attempts), isEmpty);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpWidget(_mix(catalog, player, store, clock));
    expect(find.text('Пока нет должных заданий.'), findsOneWidget);
  });

  testWidgets('two open errors are both named before the mix starts',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 8));
    final store = MemoryProgressStore(
      clock: clock,
      rules: catalog.config.masteryRules,
    );
    recordLessonResult(
      store: store,
      catalog: catalog,
      lesson: catalog.lesson('L00-02'),
      correct: 0,
      total: 2,
    );
    recordPracticeAnswer(
      store: store,
      catalog: catalog,
      setId: 'PR-03',
      correct: false,
    );
    await tester.pumpWidget(_mix(catalog, player, store, clock));
    expect(find.textContaining('Выше и ниже'), findsOneWidget);
    expect(find.textContaining('Интервалы на слух'), findsOneWidget);
  });

  test('the catalog daily mix lasts five minutes', () {
    expect(dailyMixLimit(catalog.config.raw), const Duration(minutes: 5));
  });

  testWidgets('a return due tomorrow opens note reading the next day',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 8));
    final store = MemoryProgressStore(
      clock: clock,
      rules: catalog.config.masteryRules,
    );
    store.scheduleNextDayReturn('PR-08');

    await tester.pumpWidget(_mix(catalog, player, store, clock));
    expect(find.text('Пока нет должных заданий.'), findsOneWidget);
    expect(find.text('Начать'), findsNothing);

    clock.advance(const Duration(days: 1));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpWidget(
      MaterialApp(
        home: practiceSetScreen(
          setId: 'PR-15',
          player: player,
          catalog: catalog,
          progress: store,
          clock: clock,
        ),
      ),
    );
    await tester.tap(find.text('Начать'));
    await tester.pump();
    expect(find.text('Опоры и соседи (C4–G4)'), findsOneWidget);
    expect(find.text('м3'), findsNothing);
  });

  test('a successful error return waits the configured three days', () {
    expect(errorReturnSuccessDays(catalog.config.raw), 3);
  });

  testWidgets('a correct due note waits three days before it leads again',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 8));
    final store = MemoryProgressStore(
      clock: clock,
      rules: catalog.config.masteryRules,
    );
    store.scheduleNextDayReturn('PR-08');
    clock.advance(const Duration(days: 1));

    await tester.pumpWidget(_mix(catalog, player, store, clock));
    await tester.tap(find.text('Начать'));
    await tester.pump();
    expect(find.text('Опоры и соседи (C4–G4)'), findsOneWidget);
    await tester.tap(find.text('до'));
    await tester.pump();
    expect(
      store.book.returns.single.dueAt,
      clock.now().add(const Duration(days: 3)),
    );

    clock.advance(const Duration(days: 1));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpWidget(_mix(catalog, player, store, clock));
    expect(find.text('Пока нет должных заданий.'), findsOneWidget);
    expect(find.text('Начать'), findsNothing);

    clock.advance(const Duration(days: 2));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpWidget(_mix(catalog, player, store, clock));
    await tester.tap(find.text('Начать'));
    await tester.pump();
    expect(find.text('Опоры и соседи (C4–G4)'), findsOneWidget);
  });
}

Widget _mix(
  CurriculumCatalog catalog,
  FakePracticeAudioPlayer player,
  MemoryProgressStore store,
  Clock clock,
) {
  return MaterialApp(
    home: practiceSetScreen(
      setId: 'PR-15',
      player: player,
      catalog: catalog,
      progress: store,
      clock: clock,
    ),
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
      jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
