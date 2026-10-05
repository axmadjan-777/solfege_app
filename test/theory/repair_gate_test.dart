import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/practice_attempt.dart';
import 'package:solfege_app/features/practice/progress/progress_rules.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/practice/screens/error_queue_screen.dart';
import 'package:solfege_app/features/practice/trainers/error_queue.dart';
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

  test('two reviews on a track still open the next lesson', () {
    final lesson = catalog.lesson('L00-02');
    const waiting = {'snd.pitch_direction', 'snd.duration_contrast'};
    expect(
      lessonGate(
        lesson: lesson,
        catalog: catalog,
        isMastered: (id) => id == 'snd.tone_vs_noise',
        needsReview: waiting.contains,
      ),
      LessonGate.open,
    );
  });

  testWidgets('three reviews on a track keep the next lesson on repair',
      (tester) async {
    const waiting = {
      'snd.pitch_direction',
      'snd.duration_contrast',
      'snd.timbre_dynamics'
    };
    await tester.pumpWidget(
      MaterialApp(
        home: TheoryHomeScreen(
          catalog: catalog,
          isMastered: (id) => id == 'snd.tone_vs_noise',
          needsReview: waiting.contains,
        ),
      ),
    );

    expect(
      find.descendant(
          of: find.byKey(const Key('lesson-L00-02')),
          matching: find.text('Повторение')),
      findsOneWidget,
    );
    await tester.tap(find.text('Выше и ниже'));
    await tester.pump();
    expect(find.text('Дальше'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: TheoryHomeScreen(
          catalog: catalog,
          isMastered: (id) => id == 'snd.tone_vs_noise',
          needsReview: (id) =>
              id == 'snd.pitch_direction' || id == 'snd.duration_contrast',
        ),
      ),
    );
    expect(
      find.descendant(
          of: find.byKey(const Key('lesson-L00-02')),
          matching: find.text('Открыто')),
      findsOneWidget,
    );
  });

  test('open tags stay on their skill track', () {
    final store = MemoryProgressStore(
      clock: FixedClock(DateTime.utc(2026, 10, 5, 8)),
      rules: catalog.config.masteryRules,
    );
    recordLessonResult(
      store: store,
      catalog: catalog,
      lesson: catalog.lesson('L00-02'),
      correct: 0,
      total: 2,
    );
    recordLessonResult(
      store: store,
      catalog: catalog,
      lesson: catalog.lesson('L00-06'),
      correct: 0,
      total: 2,
    );

    expect(
      ErrorQueue.openTagsOnTrack(
        attempts: store.book.attempts,
        catalog: catalog,
        skillTrack: 'perception',
      ),
      ['L00-02'],
    );
    expect(
      ErrorQueue.openTagsOnTrack(
        attempts: store.book.attempts,
        catalog: catalog,
        skillTrack: 'rhythm',
      ),
      ['L00-06'],
    );
  });

  testWidgets('repair row opens the error queue of that skill track',
      (tester) async {
    final store = MemoryProgressStore(
      clock: FixedClock(DateTime.utc(2026, 10, 5, 8)),
      rules: catalog.config.masteryRules,
    );
    recordLessonResult(
      store: store,
      catalog: catalog,
      lesson: catalog.lesson('L00-02'),
      correct: 0,
      total: 2,
    );
    recordLessonResult(
      store: store,
      catalog: catalog,
      lesson: catalog.lesson('L00-06'),
      correct: 0,
      total: 2,
    );
    const waiting = {
      'snd.pitch_direction',
      'snd.duration_contrast',
      'snd.timbre_dynamics',
    };
    await tester.pumpWidget(
      MaterialApp(
        home: TheoryHomeScreen(
          catalog: catalog,
          progress: store,
          isMastered: (id) => id == 'snd.tone_vs_noise',
          needsReview: waiting.contains,
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('lesson-L00-02')),
        matching: find.text('Повторение'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Выше и ниже'));
    await tester.pumpAndSettle();

    expect(find.text('Работа над ошибками'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ErrorQueueScreen),
        matching: find.text('Выше и ниже'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ErrorQueueScreen),
        matching: find.text('Пульс'),
      ),
      findsNothing,
    );
  });
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(
      jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
