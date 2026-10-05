import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/screens/minor_degree_screen.dart';
import 'package:solfege_app/features/practice/trainers/degree_dictation.dart';
import 'package:solfege_app/features/practice/trainers/minor_degree_dictation.dart';

void main() {
  test('natural minor third is 3 semitones and raised seven is not the natural seven', () {
    const tonic = 57;
    expect(MinorDegreeDictation.degreeLabel(tonic, 57), '1');
    expect(MinorDegreeDictation.degreeLabel(tonic, 69), '1');
    expect(MinorDegreeDictation.degreeLabel(tonic, 60), '3');
    expect(MinorDegreeDictation.degreeLabel(tonic, 67), '7');
    expect(MinorDegreeDictation.degreeLabel(tonic, 68), '7#');
    expect(DegreeDictation.degreeNumber(tonic, 60), -1);
    expect(MinorDegreeDictation.accepts(tonicMidi: tonic, noteMidi: 68, answer: '7'), isFalse);
    expect(MinorDegreeDictation.accepts(tonicMidi: tonic, noteMidi: 68, answer: '7#'), isTrue);
  });

  test('every PR-02 stage hides notation', () {
    final catalog = _catalog();
    final stages = catalog.practiceSet('PR-02').stages;
    expect(stages, hasLength(6));
    expect(stages.every((stage) => stage.params['show_notation'] == false), isTrue);
  });

  testWidgets('a minor third does not count as having arrived home', (tester) async {
    final player = FakePracticeAudioPlayer();
    bool? home;
    await tester.pumpWidget(
      MaterialApp(
        home: MinorDegreeScreen(
          tonicMidi: 57,
          noteMidi: 60,
          player: player,
          onAnswered: (value) => home = value,
        ),
      ),
    );
    await tester.pump();
    expect(player.played.whereType<RestEvent>().single.durationMs, 500);
    expect(player.played.whereType<NoteEvent>().single.midi, 60);
    await tester.tap(find.text('вернулось домой'));
    await tester.pump();
    expect(home, isFalse);
    expect(find.text('Пока не то'), findsOneWidget);
  });
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
