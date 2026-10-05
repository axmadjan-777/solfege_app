import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/interaction/templates/level01_templates.dart';
import 'package:solfege_app/features/interaction/templates/rhythm_grid_template.dart';
import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/screens/interval_stage_screen.dart';
import 'package:solfege_app/features/practice/screens/practice_map_screen.dart';
import 'package:solfege_app/features/practice/trainers/interval_ear.dart';
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

  testWidgets('L02-08 plays the anacrusis card', (tester) async {
    final lesson = catalog.lesson('L02-08');
    final plan = Level0Plan.fromLesson(lesson);
    expect(plan.steps.first.body, lesson.plainExplanation);
    expect(plan.steps.last.body, lesson.finalTask);

    await tester.pumpWidget(MaterialApp(home: Level0Player(plan: plan, onFinished: (_) {})));
    await _tap(tester, find.text('Дальше'));
    for (final step in plan.steps.where((step) => !step.isExplanation)) {
      if (step.templateId == 'T03') {
        for (final index in step.correctIndexes) {
          await _tap(tester, find.widgetWithText(CheckboxListTile, step.options[index]));
        }
        await _tap(tester, find.text('Проверить'));
      } else {
        await _tap(tester, find.text(step.options[step.correctIndex]));
      }
      await _tap(tester, find.text('Дальше'));
    }
    expect(find.text('Тренировать'), findsOneWidget);
  });

  testWidgets('PR-03 stage 2 runs without level 5 lessons', (tester) async {
    const task = IntervalTask(bassMidi: 60, semitones: 4, label: 'б3');
    final player = FakePracticeAudioPlayer();
    bool? correct;
    await tester.pumpWidget(
      MaterialApp(
        home: IntervalStageScreen(task: task, player: player, onAnswered: (value) => correct = value),
      ),
    );

    await tester.tap(find.text('м3'));
    await tester.pump();
    expect(correct, isFalse);
    expect(player.played.whereType<NoteEvent>().map((event) => event.midi).toList(), [60, 64, 60, 63, 60, 64]);

    await tester.pumpWidget(MaterialApp(home: PracticeMapScreen(catalog: catalog)));
    await tester.scrollUntilVisible(find.text('Интервалы на слух'), 500);
    expect(
      find.descendant(of: find.byKey(const Key('practice-PR-03')), matching: find.text('Стадии 1–8')),
      findsOneWidget,
    );
  });

  testWidgets('T08 fills a bar and records the result', (tester) async {
    TemplateResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RhythmGridTemplate(
            prompt: 'Собери такт',
            beats: 2,
            palette: const ['четверть', 'восьмая'],
            expected: const ['четверть', 'четверть'],
            onResult: (value) => result = value,
          ),
        ),
      ),
    );
    final quarter = find.widgetWithText(OutlinedButton, 'четверть');
    await tester.tap(quarter);
    await tester.pump();
    await tester.tap(quarter);
    await tester.pump();
    expect(result?.feedback, 'Верно');
    expect(result?.correct, isTrue);
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
