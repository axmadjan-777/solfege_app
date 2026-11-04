import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_asset_source.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/theory/level0/level0_plan.dart';
import 'package:solfege_app/features/theory/level0/level0_player.dart';
import 'package:solfege_app/features/theory/screens/lesson_review_screen.dart';
import 'package:solfege_app/features/theory/screens/theory_home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CurriculumCatalog catalog;
  setUpAll(() async => catalog = await const CurriculumAssetSource().load());

  testWidgets(
      'fresh lesson, control practice and a delayed check open the next lesson',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 11, 4, 9));
    final store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    final lesson = catalog.lesson('L00-01');
    await tester.pumpWidget(MaterialApp(
        home: ListenableBuilder(
            listenable: store,
            builder: (context, _) => TheoryHomeScreen(
                  catalog: catalog,
                  progress: store,
                  player: FakePracticeAudioPlayer(),
                  clock: clock,
                  isMastered: (id) =>
                      store.snapshot(id).status == CompetencyStatus.mastered,
                ))));
    await _tap(tester, find.text(lesson.title));
    final plan = Level0Plan.fromLesson(lesson);
    await _completeLesson(tester, plan);
    expect(find.text('Итог'), findsOneWidget);
    expect(store.book.attempts, hasLength(11));
    expect(store.snapshot(lesson.primaryCompetency).status,
        CompetencyStatus.practicing);
    await _tap(tester, find.text('Контрольная практика'));
    expect(find.byType(LessonReviewScreen), findsOneWidget);
    await _tap(tester, find.text('Слушать'));
    await _tap(tester, find.text('можно спеть'));
    expect(store.book.attempts, hasLength(12));
    expect(store.snapshot(lesson.primaryCompetency).status,
        CompetencyStatus.provisionallyPassed);
    expect(store.snapshot(lesson.primaryCompetency).provisionalAt, clock.now());
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Начать холодную проверку'))
            .onPressed,
        isNull);

    // Reopening, rather than keeping the screen state alive, must preserve the
    // waiting gate. At 19h59 it is still impossible to start the cold check.
    await _tap(tester, find.text('К теории'));
    clock.advance(const Duration(hours: 19, minutes: 59));
    await _tap(tester, find.text('Контрольная практика'));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Начать холодную проверку'))
            .onPressed,
        isNull);
    await _tap(tester, find.text('К теории'));
    clock.advance(const Duration(minutes: 1));
    await _tap(tester, find.text('Контрольная практика'));
    await _tap(tester, find.text('Начать холодную проверку'));
    expect(find.text('Объяснение'), findsNothing);
    for (final answer in ['можно спеть', 'нельзя спеть', 'нельзя спеть']) {
      await _tap(tester, find.text('Слушать'));
      await _tap(tester, find.text(answer));
      expect(find.text('Верно'), findsNothing);
      expect(find.text('Неверно'), findsNothing);
      expect(store.book.attempts, hasLength(12));
      expect(store.snapshot(lesson.primaryCompetency).status,
          CompetencyStatus.provisionallyPassed);
    }
    await _tap(tester, find.text('Слушать'));
    await _tap(tester, find.text('можно спеть'));
    expect(find.text('Освоено'), findsOneWidget);
    expect(store.book.attempts, hasLength(16));
    final cold = store.book.attempts.where((a) => a.coldReview).toList();
    expect(cold, hasLength(4));
    expect(cold.map((a) => a.sessionId).toSet(), hasLength(1));
    expect(cold.every((a) => a.isCorrect), isTrue);
    await _tap(tester, find.text('К теории'));
    final next = find.byKey(const Key('lesson-L00-02'));
    expect(find.descendant(of: next, matching: find.text('Открыто')),
        findsOneWidget);
  });

  testWidgets('lesson completion records once before its CTA is pressed',
      (tester) async {
    final lesson = catalog.lesson('L00-01');
    final plan = Level0Plan.fromLesson(lesson);
    var completed = 0;
    var continued = 0;
    await tester.pumpWidget(MaterialApp(
        home: Level0Player(
      plan: plan,
      onCompleted: (_) => completed++,
      onFinished: (_) => continued++,
    )));
    await _completeLesson(tester, plan);
    expect(completed, 1);
    expect(continued, 0);
    await _tap(tester, find.text('К теории'));
    await _tap(tester, find.text('К теории'));
    expect(completed, 1);
    expect(continued, 2);
  });

  testWidgets(
      'failed delayed check records the actual answers and does not grant mastery',
      (tester) async {
    final clock = FixedClock(DateTime.utc(2026, 11, 4));
    final lesson = catalog.lesson('L00-01');
    final store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    store.recordSession(SessionDraft(
      competencyId: lesson.primaryCompetency,
      sessionId: 'valid-immediate-history',
      correct: List.filled(12, true),
      policy: catalog.config.policy(lesson.coldReviewPolicyId),
      tonality: 'C',
      errorTag: lesson.id,
    ));
    clock.advance(const Duration(hours: 20));
    await tester.pumpWidget(MaterialApp(
        home: LessonReviewScreen(
      lesson: lesson,
      catalog: catalog,
      progress: store,
      player: FakePracticeAudioPlayer(),
      clock: clock,
    )));
    await _tap(tester, find.text('Начать холодную проверку'));
    for (final answer in [
      'можно спеть',
      'можно спеть',
      'нельзя спеть',
      'нельзя спеть'
    ]) {
      await _tap(tester, find.text('Слушать'));
      await _tap(tester, find.text(answer));
    }
    expect(store.snapshot(lesson.primaryCompetency).status,
        CompetencyStatus.needsReview);
    expect(
        store.book.attempts.where((a) => a.coldReview).map((a) => a.isCorrect),
        [true, false, true, false]);
    expect(find.text('Нужно повторить'), findsOneWidget);
    expect(find.text('Верно 2 из 4'), findsOneWidget);
  });
  testWidgets(
      'hearing the whole signal gates answers; replay adds no attempts and exit releases audio',
      (tester) async {
    final lesson = catalog.lesson('L00-01');
    final clock = FixedClock(DateTime.utc(2026, 11, 4));
    final store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    final player = _ControlledPlayer();
    await tester.pumpWidget(MaterialApp(
        home: LessonReviewScreen(
      lesson: lesson,
      catalog: catalog,
      progress: store,
      clock: clock,
      player: player,
    )));
    final answer = find.widgetWithText(FilledButton, 'можно спеть');
    expect(tester.widget<FilledButton>(answer).onPressed, isNull);
    expect(find.textContaining('фортепиано'), findsNothing);
    await tester.tap(find.text('Слушать'));
    await tester.pump();
    expect(tester.widget<FilledButton>(answer).onPressed, isNull);
    player.completion.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(answer).onPressed, isNotNull);
    await tester.tap(find.text('Слушать'));
    await tester.pump();
    player.completion.complete();
    await tester.pumpAndSettle();
    expect(store.book.attempts, isEmpty);
    expect(player.plays, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(player.stopped, isTrue);
    expect(player.disposed, isTrue);
  });

  testWidgets('playback error keeps grading blocked and retry can recover',
      (tester) async {
    final lesson = catalog.lesson('L00-01');
    final clock = FixedClock(DateTime.utc(2026, 11, 4));
    final store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    final player = _ControlledPlayer();
    await tester.pumpWidget(MaterialApp(
        home: LessonReviewScreen(
      lesson: lesson,
      catalog: catalog,
      progress: store,
      clock: clock,
      player: player,
    )));
    await tester.tap(find.text('Слушать'));
    await tester.pump();
    player.completion.completeError(StateError('audio unavailable'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Не удалось воспроизвести звук'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'можно спеть'))
            .onPressed,
        isNull);
    expect(store.book.attempts, isEmpty);
    await tester.tap(find.text('Слушать'));
    await tester.pump();
    player.completion.complete();
    await tester.pumpAndSettle();
    await _tap(tester, find.text('можно спеть'));
    expect(store.book.attempts, hasLength(1));
  });
}

Future<void> _completeLesson(WidgetTester tester, Level0Plan plan) async {
  for (final step in plan.steps) {
    if (!step.isExplanation) {
      if (step.templateId == 'T03') {
        for (final index in step.correctIndexes) {
          await _tap(tester,
              find.widgetWithText(CheckboxListTile, step.options[index]));
        }
        await _tap(tester, find.text('Проверить'));
      } else {
        await _tap(tester, find.text(step.options[step.correctIndex]));
      }
    }
    await _tap(tester, find.text('Дальше'));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _ControlledPlayer extends FakePracticeAudioPlayer {
  Completer<void> completion = Completer<void>();
  int plays = 0;

  @override
  Future<void> play(AudioSequence sequence) {
    plays++;
    completion = Completer<void>();
    played.addAll(sequence.events);
    return completion.future;
  }
}
