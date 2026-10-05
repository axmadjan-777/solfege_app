import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../../scales/services/tone_generator.dart';
import 'audio_sequence.dart';
import 'practice_audio_player.dart';

/// Синтез вместо банка AU-01, пока лицензия фортепиано не проверена.
/// Тот же интерфейс примет сэмплы A2–C6 без смены тренажёров.
class SyntheticPracticeAudioPlayer implements PracticeAudioPlayer {
  SyntheticPracticeAudioPlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  var _stopped = false;

  @override
  Future<void> play(AudioSequence sequence) async {
    _stopped = false;
    for (final event in sequence.events) {
      if (_stopped) return;
      switch (event) {
        case ChordEvent(:final midi, :final durationMs, :final volume):
          await _playWav(ToneGenerator.wavFromChord(midi, durationMs: durationMs, volume: volume));
        case NoteEvent(:final midi, :final durationMs, :final volume):
          await _playWav(ToneGenerator.wavFromMidi(midi, durationMs: durationMs, volume: volume));
        case RestEvent(:final durationMs):
          await Future<void>.delayed(Duration(milliseconds: durationMs));
      }
    }
  }

  Future<void> _playWav(Uint8List wav) async {
    await _player.play(BytesSource(wav));
    await _player.onPlayerComplete.first;
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    _stopped = true;
    await _player.dispose();
  }
}
