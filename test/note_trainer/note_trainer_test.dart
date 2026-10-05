import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/note_trainer/audio/note_player.dart';
import 'package:solfege_app/features/note_trainer/data/song_catalog.dart';
import 'package:solfege_app/features/note_trainer/data/song_repository.dart';
import 'package:solfege_app/features/note_trainer/logic/note_pitch.dart';
import 'package:solfege_app/features/note_trainer/logic/note_trainer_controller.dart';
import 'package:solfege_app/features/note_trainer/logic/staff_geometry.dart';
import 'package:solfege_app/features/note_trainer/screens/note_trainer_screen.dart';
import 'package:solfege_app/features/note_trainer/widgets/virtual_piano_widget.dart';
import 'package:solfege_app/features/note_trainer/widgets/warmup_section.dart';

void main() {
  test('staff position 0 sits on the middle line', () {
    const top = 36.0;
    const gap = 12.0;
    expect(staffNoteY(0, top: top, lineGap: gap), top + 2 * gap);
    expect(staffNoteY(4, top: top, lineGap: gap), top + 2 * gap - 24);
  });

  test('flats and sharps of the same pitch match', () {
    expect(samePitch('Bb4', 'A#4'), isTrue);
    expect(samePitch('Eb4', 'D#4'), isTrue);
    expect(midiOf('C4'), 60);
    expect(samePitch('G4', 'F4'), isFalse);
  });

  test('catalog keeps the five motifs and every note has a tone file', () {
    expect(songCatalog.map((song) => song.title), [
      'Yesterday',
      'Bohemian Rhapsody',
      'Smells Like Teen Spirit',
      'Billie Jean',
      'I Will Always Love You',
    ]);
    final whites = [for (final key in trainerPianoKeys()) if (!key.black) key];
    expect(whites.first.note, 'C4');
    expect(whites.last.note, 'G5');
    expect(whites, hasLength(12));
    for (final song in songCatalog) {
      expect(song.expectedNotes.length, song.notePositions.length);
      for (final note in song.expectedNotes) {
        expect(File('assets/${noteAssetPath(note)}').existsSync(), isTrue, reason: note);
      }
    }
  });

  test('a wrong key does not rewind and the motif can be completed', () async {
    final repository = MemorySongRepository();
    final player = RecordingNotePlayer();
    final controller = NoteTrainerController(
      repository: repository,
      userId: 'u',
      player: player,
      wait: (_) async {},
      onMiss: () {},
    );
    await controller.load(initialSongId: 'yesterday');
    expect(controller.phase, TrainerPhase.playing);
    expect(player.played, ['G4', 'F4', 'F4']);

    await controller.onKeyTap('F4');
    expect(controller.currentNoteIndex, 0);
    expect(controller.totalPlayed, 1);
    expect(controller.shakeTick, 1);
    expect(controller.feedback, contains('Вы нажали Фа'));
    expect(controller.feedback, contains('нужна нота Соль'));

    await controller.onKeyTap('G4');
    await controller.onKeyTap('F4');
    await controller.onKeyTap('F4');
    expect(controller.phase, TrainerPhase.success);
    expect(controller.progressDone, 3);
    final songs = await repository.fetchSongsWithProgress('u');
    expect(songs.firstWhere((song) => song.id == 'yesterday').isCompleted, isTrue);
    expect(songs.firstWhere((song) => song.id == 'yesterday').score, 50);
    controller.dispose();
  });

  test('Bb4 is accepted for the enharmonic piano key', () async {
    final controller = NoteTrainerController(
      repository: MemorySongRepository(),
      userId: 'u',
      player: RecordingNotePlayer(),
      wait: (_) async {},
      onMiss: () {},
    );
    await controller.load(initialSongId: 'bohemian-rhapsody');
    await controller.onKeyTap('A#4');
    expect(controller.currentNoteIndex, 1);
    expect(controller.tone, FeedbackTone.correct);
    controller.dispose();
  });

  test('left join keeps songs that have no progress row', () {
    final merged = mergeSongsWithProgress(
      songCatalog,
      [
        {
          'user_id': 'u',
          'song_id': 'billie-jean',
          'is_completed': true,
          'score': 50,
        },
      ],
      userId: 'u',
    );
    expect(merged.first.id, 'yesterday');
    expect(merged.first.isCompleted, isFalse);
    expect(merged.firstWhere((song) => song.id == 'billie-jean').isCompleted, isTrue);
    expect(
      mergeSongsWithProgress(songCatalog, [
        {
          'user_id': 'other',
          'song_id': 'yesterday',
          'is_completed': true,
          'score': 50,
        },
      ], userId: 'u').every((song) => !song.isCompleted),
      isTrue,
    );
  });

  testWidgets('the piano hides captions and a miss shakes the message', (tester) async {
    final controller = NoteTrainerController(
      repository: MemorySongRepository(),
      userId: 'u',
      player: RecordingNotePlayer(),
      wait: (_) async {},
      onMiss: () {},
    );
    await controller.load(initialSongId: 'yesterday');
    await tester.pumpWidget(
      MaterialApp(home: NoteTrainerScreen(controller: controller)),
    );
    await tester.pump();

    expect(find.textContaining('Соль (G4)'), findsOneWidget);
    expect(find.text('до / C4'), findsOneWidget);
    expect(find.text('0 / 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('piano-eye')));
    await tester.pump();
    expect(find.text('до / C4'), findsNothing);

    final wrongKey = find.byKey(const Key('piano-key-F4'));
    await tester.ensureVisible(wrongKey);
    await tester.pump();
    await tester.tap(wrongKey);
    await tester.pump();
    expect(find.textContaining('Попробуйте еще раз!'), findsOneWidget);
    expect(controller.currentNoteIndex, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('profile warmup lists the hits and locks a finished one', (tester) async {
    final repository = MemorySongRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WarmupSection(userId: 'u', repository: repository, onOpen: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('🎶 Музыкальная разминка'), findsOneWidget);
    expect(
      find.text('Сыграй легендарные хиты по нотам и прокачай музыкальный слух!'),
      findsOneWidget,
    );
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('The Beatles'), findsOneWidget);
    expect(find.text('Легко'), findsWidgets);
    expect(find.text('🎯 Попробуй повторить'), findsWidgets);

    await repository.saveProgress('u', 'yesterday');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WarmupSection(
            key: const Key('warmup-after-save'),
            userId: 'u',
            repository: repository,
            onOpen: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('🏆 Освоено! (+50 XP)'), findsOneWidget);
  });
}
