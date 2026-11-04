import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../../scales/services/tone_generator.dart';
import 'audio_sequence.dart';
import 'noise_generator.dart';
import 'practice_audio_player.dart';

/// Синтез вместо банка AU-01, пока лицензия фортепиано не проверена.
/// Тот же интерфейс примет сэмплы A2–C6 без смены тренажёров.
class SyntheticPracticeAudioPlayer implements PracticeAudioPlayer {
  SyntheticPracticeAudioPlayer({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  var _stopped = false;
  var _generation = 0;
  Completer<void> _cancelPlayback = Completer<void>();

  @override
  Future<void> play(AudioSequence sequence) async {
    if (!_cancelPlayback.isCompleted) _cancelPlayback.complete();
    _cancelPlayback = Completer<void>();
    _stopped = false;
    final generation = ++_generation;
    for (final event in sequence.events) {
      if (_stopped || generation != _generation) return;
      switch (event) {
        case ChordEvent(:final midi, :final durationMs, :final volume):
          await _playWav(ToneGenerator.wavFromChord(midi,
              durationMs: durationMs, volume: volume));
        case NoteEvent(:final midi, :final durationMs, :final volume):
          await _playWav(ToneGenerator.wavFromMidi(midi,
              durationMs: durationMs, volume: volume));
        case NoiseEvent(:final seed, :final durationMs, :final volume):
          await _playWav(NoiseGenerator.wav(
              seed: seed, durationMs: durationMs, volume: volume));
        case RestEvent(:final durationMs):
          await Future<void>.delayed(Duration(milliseconds: durationMs));
      }
    }
  }

  Future<void> _playWav(Uint8List wav) async {
    // Subscribe before starting: short buffers can finish during play().
    final cancellation = _cancelPlayback.future;
    final completed = Completer<void>();
    final subscription = _player.onPlayerComplete.listen((_) {
      if (!completed.isCompleted) completed.complete();
    }, onError: (Object error, StackTrace stack) {
      if (!completed.isCompleted) completed.completeError(error, stack);
    });
    try {
      await Future.wait<void>([
        _player.play(BytesSource(wav)),
        Future.any<void>([completed.future, cancellation]),
      ], eagerError: true);
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _generation += 1;
    if (!_cancelPlayback.isCompleted) _cancelPlayback.complete();
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    _stopped = true;
    _generation += 1;
    if (!_cancelPlayback.isCompleted) _cancelPlayback.complete();
    await _player.dispose();
  }
}
