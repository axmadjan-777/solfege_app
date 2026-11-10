import 'package:audioplayers/audioplayers.dart';

import '../logic/note_pitch.dart';

abstract interface class NotePlayer {
  Future<void> play(String note);
}

/// Плеер владеет backend и освобождает его один раз.
abstract interface class NoteAudioBackend {
  Future<void> stop();
  Future<void> playAsset(String path);
  Future<void> dispose();
}

class _AudioPlayerBackend implements NoteAudioBackend {
  _AudioPlayerBackend(this.player);
  final AudioPlayer player;

  @override
  Future<void> stop() => player.stop();
  @override
  Future<void> playAsset(String path) => player.play(AssetSource(path));
  @override
  Future<void> dispose() => player.dispose();
}

class AssetNotePlayer implements NotePlayer {
  AssetNotePlayer({AudioPlayer? player, NoteAudioBackend? backend})
      : assert(player == null || backend == null),
        _backend = backend ?? _AudioPlayerBackend(player ?? AudioPlayer());

  final NoteAudioBackend _backend;
  Future<void> _tail = Future<void>.value();
  Future<void>? _disposal;
  var _request = 0;
  var _disposed = false;

  Future<void> dispose() {
    if (_disposed) return _disposal!;
    _disposed = true;
    _request += 1;
    return _disposal = _tail.then((_) => _backend.dispose());
  }

  @override
  Future<void> play(String note) async {
    if (_disposed) return;
    final path = noteAssetPath(note);
    final request = ++_request;
    // Serialize both stop and play: a late stop from the old request must not
    // silence a newer note. Requests superseded while waiting never start.
    final operation = _tail.then((_) async {
      if (_disposed || request != _request) return;
      await _backend.stop();
      if (_disposed || request != _request) return;
      await _backend.playAsset(path);
    });
    // A failed request remains visible to its caller, while the next request
    // can still retry playback.
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    await operation;
  }
}
