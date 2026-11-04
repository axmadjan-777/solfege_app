import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/song.dart';
import 'song_catalog.dart';

/// Песни и прогресс игрока.
///
/// SQL-миграция (дублируется в `supabase/schema.sql`):
///
/// ```sql
/// create table if not exists public.songs (
///   id text primary key,
///   title text not null,
///   artist text not null,
///   difficulty text not null check (difficulty in ('easy', 'medium', 'hard')),
///   expected_notes text[] not null,
///   note_positions int[] not null
/// );
/// create table if not exists public.user_progress (
///   user_id uuid not null references auth.users (id) on delete cascade,
///   song_id text not null references public.songs (id) on delete cascade,
///   is_completed boolean not null default false,
///   score integer not null default 0,
///   primary key (user_id, song_id)
/// );
/// ```
abstract interface class SongRepository {
  Future<List<PlayableSong>> fetchSongsWithProgress(String userId);

  Future<void> saveProgress(String userId, String songId);
}

const completionScore = 50;

List<PlayableSong> mergeSongsWithProgress(
  List<PlayableSong> songs,
  List<Map<String, dynamic>> progress, {
  required String userId,
}) {
  final bySong = <String, Map<String, dynamic>>{};
  for (final row in progress) {
    if (row['user_id'] != userId) continue;
    final songId = row['song_id'];
    if (songId is String) bySong[songId] = row;
  }
  final merged = [
    for (final song in songs)
      song.copyWith(
        isCompleted: bySong[song.id]?['is_completed'] == true,
        score: (bySong[song.id]?['score'] as num?)?.toInt() ?? 0,
      ),
  ];
  merged.sort((a, b) {
    final left = songCatalogOrder.indexOf(a.id);
    final right = songCatalogOrder.indexOf(b.id);
    return (left < 0 ? 99 : left).compareTo(right < 0 ? 99 : right);
  });
  return merged;
}

class MemorySongRepository implements SongRepository {
  MemorySongRepository({List<PlayableSong>? songs})
      : _songs = [
          for (final song in songs ?? songCatalog) song,
        ];

  final List<PlayableSong> _songs;
  final _done = <String>{};

  @override
  Future<List<PlayableSong>> fetchSongsWithProgress(String userId) async {
    final rows = [
      for (final key in _done)
        if (key.startsWith('$userId|'))
          {
            'user_id': userId,
            'song_id': key.substring(userId.length + 1),
            'is_completed': true,
            'score': completionScore,
          },
    ];
    return mergeSongsWithProgress(_songs, rows, userId: userId);
  }

  @override
  Future<void> saveProgress(String userId, String songId) async {
    _done.add('$userId|$songId');
  }
}

class SupabaseSongRepository implements SongRepository {
  SupabaseSongRepository({required this.client});

  final SupabaseClient client;

  @override
  Future<List<PlayableSong>> fetchSongsWithProgress(String userId) async {
    final rows = await client.from('songs').select(
          'id, title, artist, difficulty, expected_notes, note_positions, '
          'user_progress(user_id, is_completed, score)',
        );
    final songs = <PlayableSong>[];
    final progress = <Map<String, dynamic>>[];
    for (final row in rows) {
      songs.add(PlayableSong(
        id: row['id'] as String,
        title: row['title'] as String,
        artist: row['artist'] as String,
        difficulty: SongDifficulty.parse(row['difficulty'] as String),
        expectedNotes: [
          for (final note in row['expected_notes'] as List) '$note',
        ],
        notePositions: [
          for (final position in row['note_positions'] as List)
            (position as num).toInt(),
        ],
      ));
      final embedded = row['user_progress'];
      if (embedded is List) {
        for (final item in embedded) {
          if (item is! Map) continue;
          progress.add({
            'user_id': item['user_id'],
            'song_id': row['id'],
            'is_completed': item['is_completed'] == true,
            'score': item['score'],
          });
        }
      }
    }
    if (songs.isEmpty) return mergeSongsWithProgress(songCatalog, const [], userId: userId);
    return mergeSongsWithProgress(songs, progress, userId: userId);
  }

  @override
  Future<void> saveProgress(String userId, String songId) async {
    await client.from('user_progress').upsert(
      {
        'user_id': userId,
        'song_id': songId,
        'is_completed': true,
        'score': completionScore,
      },
      onConflict: 'user_id,song_id',
    );
  }
}
