import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/practice/screens/degree_stage_screen.dart';
import 'package:solfege_app/features/practice/trainers/degree_dictation.dart';

void main() {
  testWidgets('stage 1 plays context, accepts the tonic and records below mastered', (tester) async {
    final catalog = CurriculumCatalog.fromDecoded(
      levels: _read('levels.json'),
      sourceMap: _read('source-map.json'),
      audioManifest: _read('audio-manifest.json'),
      exercises: _read('exercises.json'),
      competencies: _read('competencies.json'),
      lessons: _read('lessons.json'),
    );
    final stage = catalog.practiceSet('PR-01').stages.first;
    expect(stage.params['show_notation'], isFalse);

    final player = FakePracticeAudioPlayer();
    final store = MemoryProgressStore(
      clock: FixedClock(DateTime.utc(2026, 10, 5, 9)),
      rules: catalog.config.masteryRules,
    );
    bool? correct;
    await tester.pumpWidget(
      MaterialApp(
        home: DegreeStageScreen(
          tonicMidi: 60,
          noteMidi: 60,
          player: player,
          feedbackCorrect: stage.feedback['correct'] as String,
          onAnswered: (value) {
            correct = value;
            store.recordSession(
              SessionDraft(
                competencyId: 'sca.tonic',
                sessionId: 'PR-01-1',
                correct: [value],
                policy: catalog.config.policy('RP-aural'),
                tonality: 'C',
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(player.played.whereType<RestEvent>().single.durationMs, 500);
    expect(player.played.whereType<NoteEvent>().single.midi, 60);
    await tester.tap(find.text('вернулось домой'));
    await tester.pump();

    expect(correct, isTrue);
    expect(find.text(stage.feedback['correct'] as String), findsOneWidget);
    expect(store.snapshot('sca.tonic').status, isNot(CompetencyStatus.mastered));
    expect(DegreeDictation.arrivedHome(60, 60), isTrue);
  });
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
}
