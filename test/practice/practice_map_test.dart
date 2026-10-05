import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/screens/practice_map_screen.dart';

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

  testWidgets('PR-01 stays locked and minor dictation waits for its lesson', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PracticeMapScreen(catalog: catalog)),
    );

    await tester.scrollUntilVisible(find.text('Ступеневый диктант в одной тональности (мажор)'), 400);
    expect(find.text('Ступеневый диктант в одной тональности (мажор)'), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('practice-PR-01')), matching: find.text('Закрыто')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(find.text('Ступеневый диктант в миноре'), 400);
    expect(
      find.descendant(of: find.byKey(const Key('practice-PR-02')), matching: find.text('Закрыто')),
      findsOneWidget,
    );
  });
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
