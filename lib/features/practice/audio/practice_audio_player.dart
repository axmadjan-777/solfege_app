import 'audio_sequence.dart';

/// Плеер практики. Тренажёры зависят от этого типа, не от audioplayers.
abstract interface class PracticeAudioPlayer {
  Future<void> play(AudioSequence sequence);

  Future<void> stop();

  Future<void> dispose();
}
