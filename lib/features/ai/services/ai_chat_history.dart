import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../models/ai_chat_message.dart';

abstract interface class AiChatHistory {
  Future<List<AiChatMessage>> load();
  Future<AiChatMessage> append(AiChatMessage message);
}

/// A screen discards in-flight work when its account changes.
abstract interface class AccountScopedAiChatHistory implements AiChatHistory {
  String? get currentOwnerId;
  Stream<String?> get ownerChanges;
}

class AiChatHistoryException implements Exception {
  const AiChatHistoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MemoryAiChatHistory implements AiChatHistory {
  MemoryAiChatHistory({List<AiChatMessage>? seed})
      : _items = [
          for (final message in seed ?? const <AiChatMessage>[])
            message.markStored(),
        ];
  final List<AiChatMessage> _items;
  @override
  Future<List<AiChatMessage>> load() async => List.unmodifiable(_items);
  @override
  Future<AiChatMessage> append(AiChatMessage message) async {
    final stored = message.markStored();
    _items.add(stored);
    return stored;
  }
}

class _HistoryRequest {
  const _HistoryRequest(this.client, this.userId, this.token);
  final SupabaseClient client;
  final String userId;
  final String token;
}

/// Requests retain their original JWT even if the shared client changes account.
class SupabaseAiChatHistory implements AccountScopedAiChatHistory {
  SupabaseAiChatHistory({SupabaseClient? client, bool Function()? configured})
      : _client = client,
        _configured = configured ?? (() => SupabaseConfig.isConfigured);

  final SupabaseClient? _client;
  final bool Function() _configured;
  final _sessions = <String, Future<String>>{};
  final _messageIds = Expando<String>();

  SupabaseClient? get _ready {
    if (!_configured()) return null;
    try {
      return _client ?? SupabaseClientProvider.client;
    } catch (_) {
      return null;
    }
  }

  @override
  String? get currentOwnerId => _ready?.auth.currentUser?.id;

  @override
  Stream<String?> get ownerChanges =>
      _ready?.auth.onAuthStateChange
          .map((state) => state.session?.user.id)
          .distinct() ??
      const Stream.empty();

  _HistoryRequest? _capture() {
    final client = _ready;
    final session = client?.auth.currentSession;
    if (client == null || session == null) return null;
    return _HistoryRequest(client, session.user.id, session.accessToken);
  }

  void _checkOwner(_HistoryRequest request) {
    if (request.client.auth.currentUser?.id != request.userId) {
      throw const AiChatHistoryException(
        'Аккаунт изменился. Откройте историю текущего пользователя.',
      );
    }
  }

  @override
  Future<List<AiChatMessage>> load() async {
    final request = _capture();
    if (request == null) return const [];
    try {
      // Concurrent devices may have created different sessions: read all own rows.
      final rows = await request.client
          .from('ai_chat_messages')
          .select('id, role, body')
          .eq('user_id', request.userId)
          .order('created_at', ascending: true)
          .order('id', ascending: true)
          .setHeader('Authorization', 'Bearer ${request.token}');
      _checkOwner(request);
      return [
        for (final row in rows)
          if (messageFromRow(row) case final message?) message,
      ];
    } on AiChatHistoryException {
      rethrow;
    } catch (_) {
      throw const AiChatHistoryException(
          'Не удалось открыть прошлые сообщения.');
    }
  }

  @override
  Future<AiChatMessage> append(AiChatMessage message) async {
    final request = _capture();
    if (request == null) {
      throw const AiChatHistoryException('Войдите, чтобы сохранить историю.');
    }
    if (message.text.trim().isEmpty || message.text.length > 8000) {
      throw const AiChatHistoryException('Это сообщение не удалось сохранить.');
    }
    final id = message.id ?? (_messageIds[message] ??= newChatMessageId());
    try {
      final sessionId = await _ensureSession(request);
      _checkOwner(request);
      final rows = await request.client
          .from('ai_chat_messages')
          .upsert({
            'id': id,
            'session_id': sessionId,
            'user_id': request.userId,
            'role': message.role.name,
            'body': message.text,
          }, onConflict: 'id', ignoreDuplicates: true)
          .select('id, role, body')
          .setHeader('Authorization', 'Bearer ${request.token}');
      _checkOwner(request);
      // Retry after a lost response finds and validates the existing immutable row.
      final saved = rows.isNotEmpty
          ? rows.single
          : await request.client
              .from('ai_chat_messages')
              .select('id, role, body')
              .eq('id', id)
              .eq('user_id', request.userId)
              .maybeSingle()
              .setHeader('Authorization', 'Bearer ${request.token}');
      _checkOwner(request);
      if (saved == null ||
          saved['id'] != id ||
          saved['role'] != message.role.name ||
          saved['body'] != message.text) {
        throw const AiChatHistoryException(
            'Это сообщение не удалось сохранить.');
      }
      return message.markStored(id: id);
    } on AiChatHistoryException {
      rethrow;
    } catch (_) {
      throw const AiChatHistoryException(
          'Сообщение осталось только на этом экране.');
    }
  }

  Future<String> _ensureSession(_HistoryRequest request) async {
    final pending = _sessions.putIfAbsent(
      request.userId,
      () => _findOrCreateSession(request),
    );
    try {
      final id = await pending;
      _checkOwner(request);
      return id;
    } catch (_) {
      if (identical(_sessions[request.userId], pending)) {
        _sessions.remove(request.userId);
      }
      rethrow;
    }
  }

  Future<String> _findOrCreateSession(_HistoryRequest request) async {
    final rows = await request.client
        .from('ai_chat_sessions')
        .select('id')
        .eq('user_id', request.userId)
        .order('created_at', ascending: false)
        .limit(1)
        .setHeader('Authorization', 'Bearer ${request.token}');
    _checkOwner(request);
    if (rows.isNotEmpty) return rows.first['id'] as String;
    final row = await request.client
        .from('ai_chat_sessions')
        .insert({
          'user_id': request.userId,
        })
        .select('id')
        .single()
        .setHeader('Authorization', 'Bearer ${request.token}');
    _checkOwner(request);
    return row['id'] as String;
  }
}

AiChatMessage? messageFromRow(Map<String, dynamic> row) {
  final text = row['body'];
  final id = row['id'];
  if (text is! String || text.trim().isEmpty || (id != null && id is! String)) {
    return null;
  }
  final role = switch (row['role']) {
    'user' => AiChatRole.user,
    'model' => AiChatRole.model,
    _ => null,
  };
  if (role == null) return null;
  return AiChatMessage(role: role, text: text, id: id as String?, stored: true);
}
