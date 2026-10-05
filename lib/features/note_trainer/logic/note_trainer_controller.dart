import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../audio/note_player.dart';
import '../data/song_repository.dart';
import '../models/song.dart';
import 'note_pitch.dart';

enum TrainerPhase { loading, listening, playing, success }

enum FeedbackTone { info, correct, wrong }

class NoteTrainerController extends ChangeNotifier {
  NoteTrainerController({
    required this.repository,
    required this.userId,
    required this.player,
    this.wait = Future<void>.delayed,
    this.onMiss = HapticFeedback.lightImpact,
  });

  final SongRepository repository;
  final String userId;
  final NotePlayer player;
  final Future<void> Function(Duration duration) wait;
  final void Function() onMiss;

  List<PlayableSong> songs = [];
  PlayableSong? song;
  TrainerPhase phase = TrainerPhase.loading;
  int currentNoteIndex = 0;
  int highlightIndex = 0;
  int totalPlayed = 0;
  int shakeTick = 0;
  String feedback = '';
  FeedbackTone tone = FeedbackTone.info;
  String? saveError;
  var _listenGeneration = 0;
  var _disposed = false;

  int get progressDone {
    final current = song;
    if (current == null) return 0;
    if (phase == TrainerPhase.success) return current.expectedNotes.length;
    if (phase == TrainerPhase.playing) return currentNoteIndex;
    return 0;
  }

  String? get activeNote {
    final current = song;
    if (current == null || current.expectedNotes.isEmpty) return null;
    if (phase == TrainerPhase.success) return current.expectedNotes.last;
    final index = phase == TrainerPhase.listening ? highlightIndex : currentNoteIndex;
    if (index < 0 || index >= current.expectedNotes.length) return null;
    return current.expectedNotes[index];
  }

  Future<void> load({String? initialSongId}) async {
    phase = TrainerPhase.loading;
    notifyListeners();
    songs = await repository.fetchSongsWithProgress(userId);
    if (_disposed) return;
    PlayableSong? initial;
    for (final item in songs) {
      if (item.id == initialSongId) initial = item;
    }
    initial ??= songs.isEmpty ? null : songs.first;
    if (initial == null) {
      phase = TrainerPhase.playing;
      notifyListeners();
      return;
    }
    await selectSong(initial);
  }

  Future<void> selectSong(PlayableSong next) async {
    _listenGeneration += 1;
    final generation = _listenGeneration;
    song = next;
    currentNoteIndex = 0;
    highlightIndex = 0;
    totalPlayed = 0;
    saveError = null;
    feedback = 'Новая песня выбрана.\nНачните играть!';
    tone = FeedbackTone.info;
    phase = TrainerPhase.listening;
    notifyListeners();
    final notes = next.expectedNotes;
    for (var i = 0; i < notes.length; i++) {
      if (_disposed || generation != _listenGeneration) return;
      highlightIndex = i;
      notifyListeners();
      await player.play(notes[i]);
      await wait(const Duration(milliseconds: 600));
    }
    if (_disposed || generation != _listenGeneration) return;
    highlightIndex = 0;
    currentNoteIndex = 0;
    phase = TrainerPhase.playing;
    notifyListeners();
  }

  Future<void> onKeyTap(String note) async {
    final current = song;
    if (current == null || phase != TrainerPhase.playing) return;
    if (currentNoteIndex >= current.expectedNotes.length) return;
    totalPlayed += 1;
    final expected = current.expectedNotes[currentNoteIndex];
    if (!samePitch(note, expected)) {
      feedback =
          'Попробуйте еще раз! Вы нажали ${shortName(note)}, а нужна нота ${shortName(expected)}';
      tone = FeedbackTone.wrong;
      shakeTick += 1;
      onMiss();
      notifyListeners();
      return;
    }
    await player.play(expected);
    if (_disposed) return;
    currentNoteIndex += 1;
    highlightIndex = currentNoteIndex >= current.expectedNotes.length
        ? current.expectedNotes.length - 1
        : currentNoteIndex;
    feedback = 'Правильно! Это нота ${shortName(expected)}';
    tone = FeedbackTone.correct;
    if (currentNoteIndex >= current.expectedNotes.length) {
      phase = TrainerPhase.success;
      notifyListeners();
      try {
        await repository.saveProgress(userId, current.id);
        final updated = current.copyWith(isCompleted: true, score: completionScore);
        song = updated;
        final index = songs.indexWhere((item) => item.id == current.id);
        if (index >= 0) songs[index] = updated;
      } catch (error) {
        saveError = '$error';
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _listenGeneration += 1;
    super.dispose();
  }
}
