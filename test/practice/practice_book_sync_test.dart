import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solfege_app/features/practice/progress/practice_book_sync.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('RPC pins owner JWT and cannot follow an auth switch to another account',
      () async {
    const a = '10000000-0000-4000-8000-000000000001';
    const b = '10000000-0000-4000-8000-000000000002';
    var identity = a;
    final started = Completer<http.Request>();
    final reply = Completer<http.Response>();
    var calls = 0;
    final client = SupabaseClient(
      'https://project.invalid',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          return http.Response(
              jsonEncode({
                'access_token': _jwt(identity),
                'refresh_token': 'refresh',
                'expires_in': 3600,
                'token_type': 'bearer',
                'user': {
                  'id': identity,
                  'aud': 'authenticated',
                  'role': 'authenticated',
                  'email': 'qa@example.invalid',
                  'created_at': '2026-11-05T00:00:00Z',
                  'app_metadata': <String, dynamic>{},
                  'user_metadata': <String, dynamic>{}
                },
              }),
              200,
              request: request,
              headers: {'content-type': 'application/json'});
        }
        calls += 1;
        expect(request.url.path, endsWith('/rpc/save_practice_book'));
        started.complete(request);
        return reply.future;
      }),
    );
    addTearDown(() async {
      if (!reply.isCompleted) reply.complete(http.Response('{}', 500));
      await client.dispose();
    });
    await client.auth.setSession('refresh-A');
    final sync = PracticeBookSync(client);
    final pending = sync.push(
        userId: a,
        book: ProgressBook.empty(userId: a),
        expectedRevision: 0,
        writeId: '40000000-0000-4000-8000-000000000001');
    final assertion =
        expectLater(pending, throwsA(isA<PracticeAccountChanged>()));
    final request = await started.future;
    expect(request.headers['authorization'], 'Bearer ${_jwt(a)}');
    expect((jsonDecode(request.body) as Map)['p_user_id'], a);
    identity = b;
    await client.auth.setSession('refresh-B');
    reply.complete(http.Response('1', 200,
        request: request, headers: {'content-type': 'application/json'}));
    await assertion;
    await expectLater(
        sync.push(
            userId: a,
            book: ProgressBook.empty(userId: a),
            expectedRevision: 1,
            writeId: '40000000-0000-4000-8000-000000000002'),
        throwsA(isA<PracticeAccountChanged>()));
    expect(calls, 1);
  });
}

String _jwt(String userId) {
  String part(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({
        'sub': userId,
        'role': 'authenticated',
        'exp': 4102444800
      })}.test';
}
