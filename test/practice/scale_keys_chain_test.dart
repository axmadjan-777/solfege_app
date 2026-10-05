import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/practice/screens/practice_map_screen.dart';
import 'package:solfege_app/features/practice/screens/scale_keys_screen.dart';
import 'package:solfege_app/features/practice/trainers/scale_keys.dart';

void main() {
  testWidgets('PR-05 stage 5 records a relative-key answer below mastered', (tester) async {
    final catalog = CurriculumCatalog.fromDecoded(
      levels: _read('levels.json'),
      sourceMap: _read('source-map.json'),
      audioManifest: _read('audio-manifest.json'),
      exercises: _read('exercises.json'),
      competencies: _read('competencies.json'),
      lessons: _read('lessons.json'),
    );
    final stage = catalog.practiceSet('PR-05').stages[4];
    expect(stage.title, 'Квинтовый круг и параллельные тональности');
    expect(stage.mvpStatus.id, 'v1.1');
    expect(pr05LaterStageOpen(5, (id) => id == 'sca.circle_of_fifths'), isFalse);

    final store = MemoryProgressStore(
      clock: FixedClock(DateTime.utc(2026, 10, 5, 12)),
      rules: catalog.config.masteryRules,
    );
    bool? correct;
    await tester.pumpWidget(
      MaterialApp(
        home: RelativeKeyScreen(
          major: 'до',
          choices: const ['ля', 'до'],
          correctFeedback: stage.feedback['correct'] as String,
          firstError: stage.feedback['first_error'] as String,
          repeatError: stage.feedback['repeat_error'] as String,
          onAnswered: (value) {
            correct = value;
            store.recordSession(
              SessionDraft(
                competencyId: 'sca.relative_keys',
                sessionId: 'PR-05-5',
                correct: [value],
                policy: catalog.config.policy('RP-knowledge'),
                tonality: 'C',
                errorTag: value ? '' : 'parallel_for_relative',
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('ля минор'));
    await tester.pump();

    expect(correct, isTrue);
    expect(find.text(stage.feedback['correct'] as String), findsOneWidget);
    expect(store.book.attempts.single.isCorrect, isTrue);
    expect(store.snapshot('sca.relative_keys').status, isNot(CompetencyStatus.mastered));

    await tester.pumpWidget(
      MaterialApp(
        home: PracticeMapScreen(
          catalog: catalog,
          isMastered: (id) => id == 'sca.major_formula' || id == 'sca.c_major' || id == 'sca.major_g_f',
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Гаммы, лады, знаки и тональности: построение'), 500);
    expect(
      find.descendant(of: find.byKey(const Key('practice-PR-05')), matching: find.text('Стадии 1–5')),
      findsOneWidget,
    );
  });
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
