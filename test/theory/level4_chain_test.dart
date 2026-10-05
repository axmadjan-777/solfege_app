import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/interaction/templates/scale_builder_template.dart';
import 'package:solfege_app/features/practice/screens/practice_map_screen.dart';
import 'package:solfege_app/features/theory/level0/level0_plan.dart';
import 'package:solfege_app/features/theory/level0/level0_player.dart';

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

  testWidgets('PR-01 stays locked until both degree lessons are mastered', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PracticeMapScreen(catalog: catalog)));
    await tester.scrollUntilVisible(find.text('Ступеневый диктант в одной тональности (мажор)'), 500);
    expect(
      find.descendant(of: find.byKey(const Key('practice-PR-01')), matching: find.text('Закрыто')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PracticeMapScreen(
          catalog: catalog,
          isMastered: (id) => id == 'sca.tonic' || id == 'sca.degree_method',
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('Ступеневый диктант в одной тональности (мажор)'), 500);
    expect(
      find.descendant(of: find.byKey(const Key('practice-PR-01')), matching: find.text('Открыто')),
      findsOneWidget,
    );
  });

  testWidgets('L04-11 finishes with a link to PR-01', (tester) async {
    final plan = Level0Plan.fromLesson(catalog.lesson('L04-11'));
    expect(plan.steps.first.body, catalog.lesson('L04-11').plainExplanation);
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
    expect(result?.trainPracticeSetIds, ['PR-01']);
  });

  test('major scale formula is tone tone semitone', () {
    expect(
      isMajorScale(const ['тон', 'тон', 'полутон', 'тон', 'тон', 'тон', 'полутон']),
      isTrue,
    );
    expect(isMajorScale(const ['тон', 'полутон']), isFalse);
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
