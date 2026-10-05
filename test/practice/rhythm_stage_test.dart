import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/audio/practice_audio_player.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/practice/screens/rhythm_stage_screen.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  testWidgets('locked pulse stage does not start', (tester) async {
    final player = FakePracticeAudioPlayer();
    await tester.pumpWidget(
      MaterialApp(
        home: RhythmStageScreen(unlocked: false, player: player, onHit: (_) {}),
      ),
    );
    expect(find.textContaining('Закрыто'), findsOneWidget);
    expect(player.played, isEmpty);
  });

  testWidgets('stage 1 records a hit on rhy.pulse_tap', (tester) async {
    final catalog = _catalog();
    final player = FakePracticeAudioPlayer();
    final store = MemoryProgressStore(
      clock: FixedClock(DateTime.utc(2026, 10, 5, 10)),
      rules: catalog.config.masteryRules,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RhythmStageScreen(
          unlocked: true,
          player: player,
          onHit: (hit) {
            store.recordSession(
              SessionDraft(
                competencyId: 'rhy.pulse_tap',
                sessionId: 'PR-09-1',
                correct: [hit],
                policy: catalog.config.policy('RP-motor'),
                tonality: 'C',
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(player.played, isNotEmpty);
    await tester.tap(find.text('Тап'));
    await tester.pump();
    expect(find.text('Верно'), findsOneWidget);
    expect(store.book.attempts.single.competencyId, 'rhy.pulse_tap');
    expect(store.snapshot('rhy.pulse_tap').status, isNot(CompetencyStatus.mastered));
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
