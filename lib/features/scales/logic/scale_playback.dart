import 'package:flutter/foundation.dart';

import '../models/scale.dart';
import '../models/scale_direction.dart';
import '../services/scale_audio_player.dart';

/// Оркестрация воспроизведения без привязки к Flutter UI.
class ScalePlayback extends ChangeNotifier {
  ScalePlayback(this._player);

  final ScaleAudioPlayer _player;
  ScaleDirection? _activeDirection;

  ScaleDirection? get activeDirection => _activeDirection;

  bool get isPlaying => _activeDirection != null;

  Future<void> play(Scale scale, ScaleDirection direction) async {
    if (isPlaying) {
      await _player.stop();
    }

    _activeDirection = direction;
    notifyListeners();

    try {
      await _player.play(scale, direction);
    } finally {
      _activeDirection = null;
      notifyListeners();
    }
  }

  String playbackMessage(Scale scale, ScaleDirection direction) {
    return 'Проигрывается: ${scale.name} (${direction.labelRu})';
  }

  Future<void> disposePlayer() => _player.dispose();
}
