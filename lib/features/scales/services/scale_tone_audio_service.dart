import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/scale.dart';
import '../models/scale_direction.dart';
import 'scale_audio_player.dart';
import 'tone_generator.dart';

/// Воспроизведение гамм через программно сгенерированные тоны (без audio-файлов).
class ScaleToneAudioService implements ScaleAudioPlayer {
  ScaleToneAudioService({
    this.noteDuration = const Duration(milliseconds: 420),
    this.gapBetweenNotes = const Duration(milliseconds: 60),
  });

  final Duration noteDuration;
  final Duration gapBetweenNotes;

  final AudioPlayer _player = AudioPlayer();
  bool _stopped = false;
  bool _audioPrepared = false;

  Future<void> _prepareAudio() async {
    if (_audioPrepared) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setPlayerMode(PlayerMode.lowLatency);
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );
    _audioPrepared = true;
  }

  @override
  Future<void> play(Scale scale, ScaleDirection direction) async {
    _stopped = false;
    await _prepareAudio();
    final midiNotes = scale.midiSequence(direction);

    if (kDebugMode) {
      debugPrint(
        'Playing ${scale.name} (${direction.labelRu}): '
        '${scale.noteSequence(direction).join(' ')}',
      );
    }

    for (final midi in midiNotes) {
      if (_stopped) break;

      final wav = ToneGenerator.wavFromMidi(
        midi,
        durationMs: noteDuration.inMilliseconds,
      );

      await _player.play(BytesSource(wav));
      await _player.onPlayerComplete.first;
      if (_stopped) break;
      await Future<void>.delayed(gapBetweenNotes);
    }
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
