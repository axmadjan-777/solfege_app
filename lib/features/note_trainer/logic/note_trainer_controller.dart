import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../audio/note_player.dart';
import '../data/song_repository.dart';
import '../models/song.dart';
import 'note_pitch.dart';

enum TrainerPhase {
  loading,
  listening,
  playing,
  saving,
  saveFailed,
  success,
  error
}

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
  bool sessionExpired = false;
  var _generation = 0;
  var _disposed = false;
  var _inputBusy = false;

  bool _active(int generation) =>
      !_disposed && !sessionExpired && generation == _generation;

  int get progressDone => song == null ? 0 : currentNoteIndex;

  String? get activeNote {
    final current = song;
    if (current == null || current.expectedNotes.isEmpty) return null;
    final index =
        phase == TrainerPhase.listening ? highlightIndex : currentNoteIndex;
    return current
        .expectedNotes[index.clamp(0, current.expectedNotes.length - 1)];
  }

  Future<void> load({String? initialSongId}) async {
    if (_disposed || sessionExpired) return;
    final generation = ++_generation;
    _inputBusy = false;
    phase = TrainerPhase.loading;
    saveError = null;
    notifyListeners();
    try {
      final loaded = await repository.fetchSongsWithProgress(userId);
      if (!_active(generation)) return;
      songs = loaded;
      if (songs.isEmpty) {
        song = null;
        phase = TrainerPhase.error;
        feedback = 'Песен пока нет. Попробуйте загрузить их ещё раз.';
        notifyListeners();
        return;
      }
      await selectSong(songs.firstWhere(
        (item) => item.id == initialSongId,
        orElse: () => songs.first,
      ));
    } catch (_) {
      if (!_active(generation)) return;
      song = null;
      songs = [];
      phase = TrainerPhase.error;
      feedback =
          'Не удалось загрузить песни. Проверьте соединение и повторите.';
      notifyListeners();
    }
  }

  Future<void> selectSong(PlayableSong next) async {
    if (_disposed || sessionExpired) return;
    final generation = ++_generation;
    _inputBusy = false;
    song = next;
    currentNoteIndex = 0;
    highlightIndex = 0;
    totalPlayed = 0;
    saveError = null;
    tone = FeedbackTone.info;
    feedback = 'Сначала послушайте мотив, затем сыграйте его на пианино.';
    phase = TrainerPhase.listening;
    notifyListeners();
    try {
      if (next.expectedNotes.isEmpty ||
          next.expectedNotes.length != next.notePositions.length) {
        throw const FormatException('Некорректная последовательность нот');
      }
      for (final note in next.expectedNotes) {
        noteAssetPath(note);
      }
      for (var i = 0; i < next.expectedNotes.length; i++) {
        if (!_active(generation)) return;
        highlightIndex = i;
        notifyListeners();
        await player.play(next.expectedNotes[i]);
        if (!_active(generation)) return;
        await wait(const Duration(milliseconds: 600));
      }
      if (!_active(generation)) return;
      highlightIndex = 0;
      phase = TrainerPhase.playing;
      feedback = 'Начните играть!';
    } catch (_) {
      if (!_active(generation)) return;
      phase = TrainerPhase.error;
      feedback =
          'Не удалось воспроизвести мотив. Повторите после проверки звука.';
    }
    if (_active(generation)) notifyListeners();
  }

  Future<void> onKeyTap(String note) async {
    final current = song;
    if (_disposed ||
        sessionExpired ||
        current == null ||
        phase != TrainerPhase.playing ||
        _inputBusy ||
        currentNoteIndex >= current.expectedNotes.length) {
      return;
    }
    final generation = _generation;
    final index = currentNoteIndex;
    totalPlayed += 1;
    final expected = current.expectedNotes[index];
    if (!samePitch(note, expected)) {
      feedback =
          'Попробуйте еще раз! Вы нажали ${shortName(note)}, а нужна нота ${shortName(expected)}';
      tone = FeedbackTone.wrong;
      shakeTick += 1;
      onMiss();
      notifyListeners();
      return;
    }
    _inputBusy = true;
    try {
      await player.play(expected);
      if (!_active(generation)) return;
      currentNoteIndex = index + 1;
      highlightIndex =
          currentNoteIndex.clamp(0, current.expectedNotes.length - 1);
      feedback = 'Правильно! Это нота ${shortName(expected)}';
      tone = FeedbackTone.correct;
      if (currentNoteIndex == current.expectedNotes.length) {
        await _saveCompletion(current, generation);
      }
    } catch (_) {
      if (!_active(generation)) return;
      feedback = 'Звук не воспроизвёлся. Нажмите эту клавишу ещё раз.';
      tone = FeedbackTone.info;
    } finally {
      if (_active(generation)) {
        _inputBusy = false;
        notifyListeners();
      }
    }
  }

  Future<void> retrySave() async {
    final current = song;
    if (_disposed ||
        sessionExpired ||
        current == null ||
        phase != TrainerPhase.saveFailed) {
      return;
    }
    await _saveCompletion(current, _generation);
  }

  Future<void> _saveCompletion(PlayableSong current, int generation) async {
    phase = TrainerPhase.saving;
    saveError = null;
    notifyListeners();
    try {
      await repository.saveProgress(userId, current.id);
      if (!_active(generation)) return;
      final updated =
          current.copyWith(isCompleted: true, score: completionScore);
      song = updated;
      songs = [
        for (final item in songs) item.id == current.id ? updated : item
      ];
      phase = TrainerPhase.success;
      feedback = 'Мотив завершён. Результат сохранён.';
    } catch (_) {
      if (!_active(generation)) return;
      phase = TrainerPhase.saveFailed;
      saveError = 'Не удалось сохранить результат. Повторите запись.';
    }
    if (_active(generation)) notifyListeners();
  }

  void invalidateSession() {
    if (_disposed || sessionExpired) return;
    sessionExpired = true;
    _generation += 1;
    songs = [];
    song = null;
    saveError = null;
    phase = TrainerPhase.error;
    feedback =
        'Сессия изменилась. Вернитесь в свой профиль и откройте разминку заново.';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation += 1;
    super.dispose();
  }
}
