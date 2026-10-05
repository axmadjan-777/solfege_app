import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/interaction/templates/find_error_template.dart';
import 'package:solfege_app/features/interaction/templates/level01_templates.dart';
import 'package:solfege_app/features/interaction/templates/staff_note_template.dart';
import 'package:solfege_app/features/theory/level0/level0_plan.dart';
import 'package:solfege_app/features/theory/level0/level0_player.dart';

void main() {
  testWidgets('L03-04 reads C4 on the staff', (tester) async {
    String? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StaffNoteTemplate(midi: 60, onAnswer: (value) => answer = value)),
      ),
    );

    expect(find.byKey(const Key('staff-name-60')), findsOneWidget);
    expect(find.text('до'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'до'));
    await tester.pump();
    expect(answer, 'до');
  });

  testWidgets('L03-10 plays the authored notes-and-rhythm card', (tester) async {
    final catalog = CurriculumCatalog.fromDecoded(
      levels: _read('levels.json'),
      sourceMap: _read('source-map.json'),
      audioManifest: _read('audio-manifest.json'),
      exercises: _read('exercises.json'),
      competencies: _read('competencies.json'),
      lessons: _read('lessons.json'),
    );
    final lesson = catalog.lesson('L03-10');
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
  });

  testWidgets('T12 records the corrected answer', (tester) async {
    TemplateResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FindErrorTemplate(
            prompt: 'На стане фа вместо ми',
            options: const ['ми', 'фа'],
            correctIndex: 0,
            onResult: (value) => result = value,
          ),
        ),
      ),
    );
    await tester.tap(find.text('ми'));
    await tester.pump();
    expect(result?.feedback, 'Верно');
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
