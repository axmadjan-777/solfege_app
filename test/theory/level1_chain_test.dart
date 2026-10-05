import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/theory/level0/level0_plan.dart';
import 'package:solfege_app/features/theory/level0/level0_player.dart';
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

  testWidgets('L01-01 is closed until L00-08 is mastered and then plays', (tester) async {
    await tester.pumpWidget(MaterialApp(home: TheoryHomeScreen(catalog: catalog)));
    await tester.scrollUntilVisible(find.text('До, Ре, Ми'), 400);
    expect(
      find.descendant(of: find.byKey(const Key('lesson-L01-01')), matching: find.text('Закрыто')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TheoryHomeScreen(catalog: catalog, isMastered: (id) => id == 'kbd.layout_groups'),
      ),
    );
    await tester.scrollUntilVisible(find.text('До, Ре, Ми'), 400);
    expect(
      find.descendant(of: find.byKey(const Key('lesson-L01-01')), matching: find.text('Открыто')),
      findsOneWidget,
    );

    final plan = Level0Plan.fromLesson(catalog.lesson('L01-01'));
    Level0Result? result;
    await tester.pumpWidget(
      MaterialApp(home: Level0Player(plan: plan, onFinished: (value) => result = value)),
    );
    await _tap(tester, find.text('Дальше'));
    for (final step in plan.steps.where((step) => !step.isExplanation)) {
      await _tap(tester, find.text(step.options[step.correctIndex]));
      await _tap(tester, find.text('Дальше'));
    }
    await _tap(tester, find.text('Тренировать'));
    expect(result?.lessonId, 'L01-01');
    expect(result?.correct, result?.total);
  });
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
