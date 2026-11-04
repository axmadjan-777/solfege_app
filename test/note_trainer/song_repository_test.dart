import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solfege_app/features/note_trainer/data/song_catalog.dart';
import 'package:solfege_app/features/note_trainer/data/song_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '00000000-0000-0000-0000-00000000000a';
const _b = '00000000-0000-0000-0000-00000000000b';

Future<void> _signIn(SupabaseClient client, String userId) {
  return client.auth.setInitialSession(jsonEncode({
    'access_token': 'test-token-$userId',
    'token_type': 'bearer',
    'user': {
      'id': userId,
      'app_metadata': {},
      'user_metadata': {},
      'aud': 'authenticated',
      'created_at': '2026-11-05T00:00:00Z'
    },
  }));
}

class _Database {
  final rows = <String, Map<String, dynamic>>{};
  final requests = <http.Request>[];
  Completer<void>? readGate;
  Completer<void>? writeGate;
  Completer<void>? requestStarted;
  bool rejectWrites = false;

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final owner = request.headers['authorization']!
        .substring('Bearer test-token-'.length);
    requestStarted?.complete();
    requestStarted = null;
    if (request.method == 'GET') {
      final captured = [
        for (final song in songCatalog)
          {
            'id': song.id,
            'title': song.title,
            'artist': song.artist,
            'difficulty': song.difficulty.id,
            'expected_notes': song.expectedNotes,
            'note_positions': song.notePositions,
            'user_progress': [
              for (final row in rows.values)
                if (row['user_id'] == owner && row['song_id'] == song.id) row
            ]
          },
      ];
      await readGate?.future;
      return http.Response(jsonEncode(captured), 200,
          headers: {'content-type': 'application/json'}, request: request);
    }
    expect(request.method, 'POST');
    expect(request.url.path, '/rest/v1/user_progress');
    expect(request.url.queryParameters['on_conflict'], 'user_id,song_id');
    expect(request.headers['prefer'], contains('resolution=merge-duplicates'));
    final row = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
    expect(row['user_id'], owner, reason: 'The pinned token must own the row');
    await writeGate?.future;
    if (rejectWrites) {
      return http.Response(
          jsonEncode({'code': '42501', 'message': 'permission denied'}), 403,
          headers: {'content-type': 'application/json'}, request: request);
    }
    rows['$owner|${row['song_id']}'] = row;
    return http.Response('', 201, request: request);
  }
}

void main() {
  late _Database database;
  late SupabaseClient client;
  late SupabaseSongRepository repository;
  setUp(() async {
    database = _Database();
    client = SupabaseClient('https://songs.example.invalid', 'public-test-key',
        httpClient: MockClient(database.handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    repository = SupabaseSongRepository(client: client);
    await _signIn(client, _a);
  });
  tearDown(() => client.dispose());

  test(
      'atomic completion upsert survives duplicate writes and repeated reload for two owners',
      () async {
    await Future.wait(
        [for (var i = 0; i < 4; i++) repository.saveProgress(_a, 'yesterday')]);
    expect(database.rows, hasLength(1));
    for (var i = 0; i < 3; i++) {
      final reloaded = await SupabaseSongRepository(client: client)
          .fetchSongsWithProgress(_a);
      expect(reloaded, hasLength(5));
      expect(reloaded.first.isCompleted, isTrue);
      expect(reloaded.first.score, 50);
      expect(reloaded.skip(1).every((song) => !song.isCompleted), isTrue);
    }
    final request = database.requests.last;
    expect(request.url.queryParameters['user_progress.user_id'], 'eq.$_a');
    await _signIn(client, _b);
    expect(
        (await repository.fetchSongsWithProgress(_b))
            .every((song) => !song.isCompleted),
        isTrue);
    await repository.saveProgress(_b, 'billie-jean');
    expect(database.rows, hasLength(2));
    await _signIn(client, _a);
    final mine = await repository.fetchSongsWithProgress(_a);
    expect(mine.first.isCompleted, isTrue);
    expect(mine.firstWhere((song) => song.id == 'billie-jean').isCompleted,
        isFalse);
    expect(database.requests.any((request) => request.method == 'DELETE'),
        isFalse);
  });

  test('mismatched owner is rejected before any HTTP request', () async {
    await expectLater(repository.fetchSongsWithProgress(_b), throwsStateError);
    await expectLater(
        repository.saveProgress(_b, 'yesterday'), throwsStateError);
    expect(database.requests, isEmpty);
  });

  test('a delayed A read is discarded after signing in as B', () async {
    database.readGate = Completer<void>();
    database.requestStarted = Completer<void>();
    final started = database.requestStarted!.future;
    final read = repository.fetchSongsWithProgress(_a);
    final failed = expectLater(read, throwsStateError);
    await started;
    await _signIn(client, _b);
    database.readGate!.complete();
    await failed;
  });

  test('an in-flight completion stays owned by A and cannot update B',
      () async {
    database.writeGate = Completer<void>();
    database.requestStarted = Completer<void>();
    final started = database.requestStarted!.future;
    final write = repository.saveProgress(_a, 'yesterday');
    final failed = expectLater(write, throwsStateError);
    await started;
    await _signIn(client, _b);
    database.writeGate!.complete();
    await failed;
    expect(database.rows.keys, ['$_a|yesterday']);
    expect(database.requests.single.headers['authorization'],
        'Bearer test-token-$_a');
  });

  test(
      'a failed transaction leaves no completion and an explicit retry is idempotent',
      () async {
    database.rejectWrites = true;
    await expectLater(repository.saveProgress(_a, 'yesterday'),
        throwsA(isA<PostgrestException>()));
    expect(database.rows, isEmpty);
    database.rejectWrites = false;
    await repository.saveProgress(_a, 'yesterday');
    await repository.saveProgress(_a, 'yesterday');
    expect(database.rows, hasLength(1));
    expect(database.rows.values.single['score'], 50);
  });
}
