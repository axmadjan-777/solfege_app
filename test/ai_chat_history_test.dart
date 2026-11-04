import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solfege_app/features/ai/models/ai_chat_message.dart';
import 'package:solfege_app/features/ai/services/ai_chat_history.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = '10000000-0000-4000-8000-000000000001';
const _b = '10000000-0000-4000-8000-000000000002';

class _Backend {
  final requests = <http.Request>[];
  final sessions = <Map<String, dynamic>>[];
  final messages = <Map<String, dynamic>>[];
  Completer<void>? sessionGate;
  Completer<void>? messagesGate;
  var dropNextAcknowledgement = false;

  late final client = SupabaseClient(
    'https://history.test',
    'test-publishable-key',
    httpClient: MockClient(_handle),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  late final history =
      SupabaseAiChatHistory(client: client, configured: () => true);

  String token(String user) => '${base64UrlEncode(utf8.encode(jsonEncode({
            'alg': 'HS256',
            'typ': 'JWT'
          }))).replaceAll('=', '')}.${base64UrlEncode(utf8.encode(jsonEncode({
            'sub': user,
            'role': 'authenticated',
            'exp': 4102444800
          }))).replaceAll('=', '')}.test-signature';

  Future<void> login(String user) async {
    await client.auth
        .signInWithPassword(email: '$user@example.test', password: 'test-only');
  }

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    http.Response respond(Object value, [int status = 200]) =>
        http.Response(jsonEncode(value), status,
            request: request, headers: {'content-type': 'application/json'});
    final path = request.url.path;
    if (path.endsWith('/token')) {
      final user =
          (jsonDecode(request.body)['email'] as String).split('@').first;
      return respond({
        'access_token': token(user),
        'refresh_token': 'refresh-$user',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': user,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': '$user@example.test',
          'created_at': '2026-01-01T00:00:00Z',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{}
        },
      });
    }
    if (path.endsWith('/ai_chat_sessions')) {
      if (request.method == 'GET') {
        await sessionGate?.future;
        final user = request.url.queryParameters['user_id']?.substring(3);
        return respond(
            sessions.where((row) => row['user_id'] == user).toList());
      }
      final row = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      row['id'] = newChatMessageId();
      sessions.add(row);
      return respond(row, 201);
    }
    if (path.endsWith('/ai_chat_messages')) {
      if (request.method == 'GET') {
        await messagesGate?.future;
        final user = request.url.queryParameters['user_id']?.substring(3);
        final id = request.url.queryParameters['id']?.substring(3);
        final rows = messages
            .where((row) =>
                row['user_id'] == user && (id == null || row['id'] == id))
            .toList();
        return respond(rows);
      }
      final row = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      if (messages.any((saved) => saved['id'] == row['id'])) return respond([]);
      messages.add(row);
      if (dropNextAcknowledgement) {
        dropNextAcknowledgement = false;
        return respond({'message': 'acknowledgement lost'}, 503);
      }
      return respond([row], 201);
    }
    throw StateError('Unexpected fake route: $path');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Backend backend;
  setUp(() => backend = _Backend());
  tearDown(() async => backend.client.dispose());

  test('A to B to A keeps session, owner filter and bearer paired', () async {
    await backend.login(_a);
    await backend.history
        .append(const AiChatMessage(role: AiChatRole.user, text: 'История A'));
    await backend.login(_b);
    await backend.history
        .append(const AiChatMessage(role: AiChatRole.user, text: 'История B'));
    final b = await backend.history.load();
    expect(b.map((row) => row.text), ['История B']);
    await backend.login(_a);
    expect(
        (await backend.history.load()).map((row) => row.text), ['История A']);
    expect(backend.sessions, hasLength(2));
    for (final message in backend.messages) {
      final session = backend.sessions
          .singleWhere((row) => row['id'] == message['session_id']);
      expect(session['user_id'], message['user_id']);
    }
    for (final request
        in backend.requests.where((r) => r.url.path.contains('/rest/'))) {
      final token = request.headers['authorization'];
      if (request.method == 'GET') {
        expect(token,
            'Bearer ${backend.token(request.url.queryParameters['user_id']!.substring(3))}');
      } else {
        expect(token,
            'Bearer ${backend.token(jsonDecode(request.body)['user_id'] as String)}');
      }
    }
  });

  test(
      'an account switch during session lookup cannot write an old question for B',
      () async {
    await backend.login(_a);
    backend.sessionGate = Completer<void>();
    final pending = backend.history
        .append(const AiChatMessage(role: AiChatRole.user, text: 'Вопрос A'));
    final assertion =
        expectLater(pending, throwsA(isA<AiChatHistoryException>()));
    await Future<void>.delayed(Duration.zero);
    await backend.login(_b);
    backend.sessionGate!.complete();
    await assertion;
    expect(backend.messages, isEmpty);
    expect(backend.sessions, isEmpty);
  });

  test(
      'late A history is rejected after switching to B and its request keeps A bearer',
      () async {
    await backend.login(_a);
    backend.messagesGate = Completer<void>();
    final pending = backend.history.load();
    final assertion =
        expectLater(pending, throwsA(isA<AiChatHistoryException>()));
    await Future<void>.delayed(Duration.zero);
    await backend.login(_b);
    backend.messagesGate!.complete();
    await assertion;
    final request = backend.requests
        .firstWhere((r) => r.url.path.endsWith('/ai_chat_messages'));
    expect(request.headers['authorization'], 'Bearer ${backend.token(_a)}');
  });

  test('concurrent appends share one session lookup', () async {
    await backend.login(_a);
    backend.sessionGate = Completer<void>();
    final first = backend.history
        .append(const AiChatMessage(role: AiChatRole.user, text: 'Первый'));
    final second = backend.history
        .append(const AiChatMessage(role: AiChatRole.model, text: 'Второй'));
    await Future<void>.delayed(Duration.zero);
    backend.sessionGate!.complete();
    await Future.wait([first, second]);
    expect(backend.sessions, hasLength(1));
    expect(backend.messages, hasLength(2));
  });

  test('retry after a lost acknowledgement stores a message only once',
      () async {
    await backend.login(_a);
    backend.dropNextAcknowledgement = true;
    final message = AiChatMessage(
        role: AiChatRole.user, text: 'Один вопрос', id: newChatMessageId());
    await expectLater(backend.history.append(message),
        throwsA(isA<AiChatHistoryException>()));
    final retried = await backend.history.append(message);
    expect(retried.stored, isTrue);
    expect(retried.id, message.id);
    expect(backend.messages, hasLength(1));
  });

  test(
      'history includes every own session instead of losing another device exchange',
      () async {
    await backend.login(_a);
    backend.messages.addAll([
      {
        'id': newChatMessageId(),
        'session_id': 'first-device',
        'user_id': _a,
        'role': 'user',
        'body': 'Первое устройство'
      },
      {
        'id': newChatMessageId(),
        'session_id': 'second-device',
        'user_id': _a,
        'role': 'model',
        'body': 'Второе устройство'
      },
      {
        'id': newChatMessageId(),
        'session_id': 'b-device',
        'user_id': _b,
        'role': 'user',
        'body': 'Чужое'
      },
    ]);
    expect((await backend.history.load()).map((row) => row.text),
        ['Первое устройство', 'Второе устройство']);
  });

  test('missing session and invalid content never claim persistence', () async {
    await expectLater(
        backend.history.append(
            const AiChatMessage(role: AiChatRole.user, text: 'До входа')),
        throwsA(isA<AiChatHistoryException>()));
    await backend.login(_a);
    await expectLater(
        backend.history
            .append(const AiChatMessage(role: AiChatRole.user, text: ' ')),
        throwsA(isA<AiChatHistoryException>()));
    await expectLater(
        backend.history
            .append(AiChatMessage(role: AiChatRole.model, text: 'a' * 8001)),
        throwsA(isA<AiChatHistoryException>()));
    expect(backend.sessions, isEmpty);
    expect(backend.messages, isEmpty);
  });
}
