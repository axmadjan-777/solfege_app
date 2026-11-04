import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/note_trainer/audio/note_player.dart';

class _Backend implements NoteAudioBackend {
  final calls = <String>[];
  Completer<void>? nextStop;
  bool failNextPlay = false;
  var disposals = 0;

  @override
  Future<void> stop() async {
    calls.add('stop');
    final gate = nextStop;
    nextStop = null;
    await gate?.future;
  }

  @override
  Future<void> playAsset(String path) async {
    calls.add('play:$path');
    if (failNextPlay) {
      failNextPlay = false;
      throw StateError('audio unavailable');
    }
  }

  @override
  Future<void> dispose() async {
    disposals += 1;
    calls.add('dispose');
  }
}

void main() {
  test(
      'a delayed old stop cannot start an obsolete note or stop its replacement',
      () async {
    final gate = Completer<void>();
    final backend = _Backend()..nextStop = gate;
    final player = AssetNotePlayer(backend: backend);
    final old = player.play('C4');
    await Future<void>.delayed(Duration.zero);
    expect(backend.calls, ['stop']);
    final replacement = player.play('D4');
    await Future<void>.delayed(Duration.zero);
    expect(backend.calls, ['stop']);
    gate.complete();
    await Future.wait([old, replacement]);
    expect(backend.calls, ['stop', 'stop', 'play:audio/D4.mp3']);
    await player.dispose();
  });

  test('disposal cancels queued playback and owns backend cleanup exactly once',
      () async {
    final gate = Completer<void>();
    final backend = _Backend()..nextStop = gate;
    final player = AssetNotePlayer(backend: backend);
    final playing = player.play('C4');
    await Future<void>.delayed(Duration.zero);
    final disposing = player.dispose();
    await player.play('D4');
    gate.complete();
    await Future.wait([playing, disposing]);
    await player.dispose();
    expect(backend.calls, ['stop', 'dispose']);
    expect(backend.disposals, 1);
  });

  test(
      'a failed native request stays visible and does not poison later playback',
      () async {
    final backend = _Backend()..failNextPlay = true;
    final player = AssetNotePlayer(backend: backend);
    await expectLater(player.play('C4'), throwsStateError);
    await player.play('D4');
    expect(backend.calls,
        ['stop', 'play:audio/C4.mp3', 'stop', 'play:audio/D4.mp3']);
    await player.dispose();
  });
}
