import 'package:flutter/foundation.dart';

import '../models/scale.dart';
import '../models/scale_direction.dart';
import 'scale_audio_player.dart';

/// Заглушка воспроизведения. Замените тело [play] на реальный player,
/// используя [Scale.midiSequence] / [Scale.noteSequence].
class ScaleAudioService implements ScaleAudioPlayer {
  const ScaleAudioService();

  @override
  Future<void> play(Scale scale, ScaleDirection direction) async {
    final sequence = scale.noteSequence(direction);
    final directionLabel = direction == ScaleDirection.ascending
        ? 'ascending'
        : 'descending';

    debugPrint(
      'Playing ${scale.name} $directionLabel: ${sequence.join(' ')}',
    );

    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> stop() async {
    debugPrint('Scale playback stopped');
  }

  @override
  Future<void> dispose() async {}
}
