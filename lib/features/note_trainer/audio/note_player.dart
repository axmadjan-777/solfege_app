import 'package:audioplayers/audioplayers.dart';

import '../logic/note_pitch.dart';

abstract interface class NotePlayer {
  Future<void> play(String note);
}

class AssetNotePlayer implements NotePlayer {
  AssetNotePlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  Future<void> dispose() => _player.dispose();

  @override
  Future<void> play(String note) async {
    await _player.stop();
    await _player.play(AssetSource(noteAssetPath(note)));
  }
}

class RecordingNotePlayer implements NotePlayer {
  final played = <String>[];

  @override
  Future<void> play(String note) async {
    played.add(note);
  }
}
