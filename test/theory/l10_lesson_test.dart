import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/screens/practice_map_screen.dart';
import 'package:solfege_app/features/theory/level0/level0_plan.dart';
import 'package:solfege_app/features/theory/level0/level0_player.dart';

void main() {
  testWidgets('L10-05 plays the dictation method card', (tester) async {
    final catalog = _catalog();
    final lesson = catalog.lesson('L10-05');
    final plan = Level0Plan.fromLesson(lesson);
    expect(plan.steps.first.body, lesson.plainExplanation);
    expect(plan.steps.last.body, lesson.finalTask);

    await tester.pumpWidget(MaterialApp(home: Level0Player(plan: plan, onFinished: (_) {})));
    await _tap(tester, find.text('Дальше'));
    for (final step in plan.steps.where((step) => !step.isExplanation)) {
      await _tap(tester, find.text(step.options[step.correctIndex]));
      await _tap(tester, find.text('Дальше'));
    }
    expect(find.text('Тренировать'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: PracticeMapScreen(catalog: catalog)));
    await tester.scrollUntilVisible(find.text('Ритмический диктант'), 500);
    expect(
      find.descendant(of: find.byKey(const Key('practice-PR-10')), matching: find.text('Закрыто')),
      findsOneWidget,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeMapScreen(catalog: catalog, isMastered: (id) => id == 'wrt.rhythm_dictation'),
      ),
    );
    await tester.scrollUntilVisible(find.text('Ритмический диктант'), 500);
    expect(
      find.descendant(of: find.byKey(const Key('practice-PR-10')), matching: find.text('Открыто')),
      findsOneWidget,
    );
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
    return Map<String, dynamic>.from(jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
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
