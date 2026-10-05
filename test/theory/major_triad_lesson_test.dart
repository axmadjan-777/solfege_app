import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/screens/practice_map_screen.dart';
import 'package:solfege_app/features/practice/trainers/triad_formulas.dart';
import 'package:solfege_app/features/theory/level0/level0_plan.dart';
import 'package:solfege_app/features/theory/level0/level0_player.dart';

void main() {
  testWidgets('L08-02 teaches 0-4-7 and keeps chord hearing closed without that competency', (tester) async {
    final catalog = _catalog();
    final lesson = catalog.lesson('L08-02');
    final plan = Level0Plan.fromLesson(lesson);

    expect(plan.steps.first.body, lesson.plainExplanation);
    expect(plan.steps[1].options[plan.steps[1].correctIndex], '0–4–7');
    expect(TriadFormulas.major, [0, 4, 7]);

    await tester.pumpWidget(MaterialApp(home: Level0Player(plan: plan, onFinished: (_) {})));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('0–4–7'));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('0–3–7'));
    await _tap(tester, find.text('Дальше'));
    await _tap(tester, find.text('0–4–7'));
    await _tap(tester, find.text('Дальше'));
    expect(find.text('Тренировать'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: PracticeMapScreen(catalog: catalog)));
    await tester.scrollUntilVisible(find.text('Аккорды на слух'), 500);
    expect(
      find.descendant(of: find.byKey(const Key('practice-PR-06')), matching: find.text('Закрыто')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PracticeMapScreen(
          catalog: catalog,
          isMastered: (id) => pr06Required.contains(id) && id != 'chd.major_triad',
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Аккорды на слух'), 500);
    expect(
      find.descendant(of: find.byKey(const Key('practice-PR-06')), matching: find.text('Закрыто')),
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
