import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/progress/progress_rules.dart';
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
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(
      jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
