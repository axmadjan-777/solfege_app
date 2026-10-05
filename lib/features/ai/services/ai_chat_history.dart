import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../models/ai_chat_message.dart';

abstract interface class AiChatHistory {
  Future<List<AiChatMessage>> load();

  Future<AiChatMessage> append(AiChatMessage message);
}

class AiChatHistoryException implements Exception {
  const AiChatHistoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MemoryAiChatHistory implements AiChatHistory {
  MemoryAiChatHistory({List<AiChatMessage>? seed})
      : _items = [for (final message in seed ?? const <AiChatMessage>[]) message.markStored()];

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

/// Сессия и сообщения текущего пользователя. Без входа история остаётся на экране.
class SupabaseAiChatHistory implements AiChatHistory {
  SupabaseAiChatHistory({SupabaseClient? client, bool Function()? configured})
      : _client = client,
        _configured = configured ?? (() => SupabaseConfig.isConfigured);

  final SupabaseClient? _client;
  final bool Function() _configured;
  String? _sessionId;

  SupabaseClient? get _ready {
    if (!_configured()) return null;
    try {
      return _client ?? SupabaseClientProvider.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<AiChatMessage>> load() async {
    final client = _ready;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return const [];
    try {
      final sessionId = await _latestSession(client, user.id);
      if (sessionId == null) return const [];
      _sessionId = sessionId;
      final rows = await client
          .from('ai_chat_messages')
          .select('id, role, body')
          .eq('session_id', sessionId)
          .order('created_at');
      final messages = <AiChatMessage>[];
      for (final row in rows) {
        final message = messageFromRow(Map<String, dynamic>.from(row));
        if (message != null) messages.add(message);
      }
      return messages;
    } catch (_) {
      throw const AiChatHistoryException('Не удалось открыть прошлые сообщения.');
    }
  }

  @override
  Future<AiChatMessage> append(AiChatMessage message) async {
    final client = _ready;
    final user = client?.auth.currentUser;
    if (client == null || user == null || message.text.trim().isEmpty) {
      return message.markStored();
    }
    final sessionId = await _ensureSession(client, user.id);
    final body = message.text.length > 8000 ? message.text.substring(0, 8000) : message.text;
    final row = await client.from('ai_chat_messages').insert({
      'session_id': sessionId,
      'user_id': user.id,
      'role': message.role.name,
      'body': body,
    }).select('id').single();
    return message.markStored(id: row['id'] as String?);
  }

  Future<String?> _latestSession(SupabaseClient client, String userId) async {
    final rows = await client
        .from('ai_chat_sessions')
        .select('id')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['id'] as String?;
  }

  Future<String> _ensureSession(SupabaseClient client, String userId) async {
    final cached = _sessionId;
    if (cached != null) return cached;
    final existing = await _latestSession(client, userId);
    if (existing != null) {
      _sessionId = existing;
      return existing;
    }
    final created = await client.from('ai_chat_sessions').insert({
      'user_id': userId,
    }).select('id').single();
    final id = created['id'] as String;
    _sessionId = id;
    return id;
  }
}

AiChatMessage? messageFromRow(Map<String, dynamic> row) {
  final roleName = row['role'];
  final text = row['body'];
  if (text is! String || text.isEmpty) return null;
  final role = switch (roleName) {
    'user' => AiChatRole.user,
    'model' => AiChatRole.model,
    _ => null,
  };
  if (role == null) return null;
  return AiChatMessage(
    role: role,
    text: text,
    id: row['id'] as String?,
    stored: true,
  );
}
