import 'audio_sequence.dart';

/// Плеер практики. Тренажёры зависят от этого типа, не от audioplayers.
abstract interface class PracticeAudioPlayer {
  Future<void> play(AudioSequence sequence);

  Future<void> stop();

  Future<void> dispose();
}

/// Записывает события и молчит. Для L2 и виджет-тестов.
class FakePracticeAudioPlayer implements PracticeAudioPlayer {
  final played = <AudioEvent>[];
  var stopped = false;
  var disposed = false;

  @override
  Future<void> play(AudioSequence sequence) async {
    played.addAll(sequence.events);
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
