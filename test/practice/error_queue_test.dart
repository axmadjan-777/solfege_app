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
import 'package:solfege_app/features/practice/screens/error_queue_screen.dart';
import 'package:solfege_app/features/practice/trainers/error_queue.dart';

void main() {
  late CurriculumCatalog catalog;

  setUpAll(() => catalog = _catalog());

  test('two different PR-01 cards with one error tag make one queue entry', () {
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 8));
    final store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    final policy = catalog.config.policy('RP-aural');

    store.recordSession(
      SessionDraft(
        competencyId: 'ear.degree.major.4',
        sessionId: 'card-a',
        correct: const [false],
        policy: policy,
        tonality: 'C',
        errorTag: 'degree.4-vs-6',
        itemSignature: 'PR-01-stage6-a',
      ),
    );
    store.recordSession(
      SessionDraft(
        competencyId: 'ear.degree.major.4',
        sessionId: 'card-b',
        correct: const [false],
        policy: policy,
        tonality: 'G',
        errorTag: 'degree.4-vs-6',
        itemSignature: 'PR-01-stage6-b',
      ),
    );

    expect(store.book.attempts.map((attempt) => attempt.itemSignature).toSet(),
        hasLength(2));
    expect(ErrorQueue.openTags(store.book.attempts), ['degree.4-vs-6']);
    expect(ErrorQueue.repairInsteadOfNewLesson(3), isTrue);
    expect(ErrorQueue.repairInsteadOfNewLesson(2), isFalse);
  });

  testWidgets('empty queue is calm, and a tag appears only after a miss',
      (tester) async {
    final store = MemoryProgressStore(
      clock: FixedClock(DateTime.utc(2026, 10, 5, 8)),
      rules: catalog.config.masteryRules,
    );
    await tester.pumpWidget(
      MaterialApp(home: ErrorQueueScreen(store: store, onColdReview: (_) {})),
    );
    expect(find.text('Очередь пуста. Новых ошибок нет.'), findsOneWidget);

    store.recordSession(
      SessionDraft(
        competencyId: 'ear.degree.major.6',
        sessionId: 'miss',
        correct: const [false],
        policy: catalog.config.policy('RP-aural'),
        tonality: 'C',
        errorTag: 'degree.4-vs-6',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: ErrorQueueScreen(store: store, onColdReview: (_) {})),
    );
    expect(find.text('degree.4-vs-6'), findsOneWidget);
    expect(find.text('Очередь пуста. Новых ошибок нет.'), findsNothing);
  });

  testWidgets(
      'a lesson miss shows its title and a correct retry clears the queue',
      (tester) async {
    final store = MemoryProgressStore(
      clock: FixedClock(DateTime.utc(2026, 10, 5, 8)),
      rules: catalog.config.masteryRules,
    );
    final lesson = catalog.lesson('L00-02');
    recordLessonResult(
        store: store, catalog: catalog, lesson: lesson, correct: 0, total: 2);
    await tester.pumpWidget(
      MaterialApp(
          home: ErrorQueueScreen(
              store: store, catalog: catalog, onColdReview: (_) {})),
    );
    expect(find.text(lesson.title), findsOneWidget);

    await tester.tap(find.text(lesson.title));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('выше'));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('так же'));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('Тренировать'));
    await tester.pumpAndSettle();

    expect(find.text('Очередь пуста. Новых ошибок нет.'), findsOneWidget);
    expect(ErrorQueue.openTags(store.book.attempts), isEmpty);
    expect(store.snapshot(lesson.primaryCompetency).status,
        isNot(CompetencyStatus.mastered));
  });

  testWidgets(
      'a trainer miss opens that trainer and a correct answer clears it',
      (tester) async {
    final store = MemoryProgressStore(
      clock: FixedClock(DateTime.utc(2026, 10, 5, 8)),
      rules: catalog.config.masteryRules,
    );
    recordPracticeAnswer(
        store: store, catalog: catalog, setId: 'PR-03', correct: false);
    final title =
        catalog.practiceSets.firstWhere((set) => set.id == 'PR-03').title;
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorQueueScreen(
          store: store,
          catalog: catalog,
          player: FakePracticeAudioPlayer(),
          clock: FixedClock(DateTime.utc(2026, 10, 5, 8)),
          onColdReview: (_) {},
        ),
      ),
    );
    expect(find.text(title), findsOneWidget);

    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    expect(find.text('м3'), findsOneWidget);
    await tester.tap(find.text('м3'));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Очередь пуста. Новых ошибок нет.'), findsOneWidget);
    expect(ErrorQueue.openTags(store.book.attempts), isEmpty);
    expect(
      store
          .snapshot(competencyOf(
              catalog.practiceSets.firstWhere((set) => set.id == 'PR-03')))
          .status,
      isNot(CompetencyStatus.mastered),
    );
  });

  test('cold review 20 hours later grants mastered and the same hour does not',
      () {
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 8));
    final store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    final policy = catalog.config.policy('RP-aural');
    store.recordSession(
      SessionDraft(
        competencyId: 'ear.degree.major.1',
        sessionId: 'learn',
        correct: List<bool>.filled(12, true),
        policy: policy,
        tonality: 'C',
      ),
    );
    store.recordSession(
      SessionDraft(
        competencyId: 'ear.degree.major.1',
        sessionId: 'too-soon',
        correct: List<bool>.filled(4, true),
        policy: policy,
        tonality: 'G',
        coldReview: true,
      ),
    );
    expect(store.snapshot('ear.degree.major.1').status,
        CompetencyStatus.provisionallyPassed);

    clock.advance(const Duration(hours: 20));
    store.recordSession(
      SessionDraft(
        competencyId: 'ear.degree.major.1',
        sessionId: 'cold',
        correct: List<bool>.filled(4, true),
        policy: policy,
        tonality: 'G',
        coldReview: true,
      ),
    );
    expect(
        store.snapshot('ear.degree.major.1').status, CompetencyStatus.mastered);
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

CurriculumCatalog _catalog() {
  Map<String, dynamic> read(String name) {
    return Map<String, dynamic>.from(
        jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
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
