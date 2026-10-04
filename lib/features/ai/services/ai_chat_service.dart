import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../models/ai_chat_message.dart';

abstract interface class AiChatService {
  Future<String> send(List<AiChatMessage> messages);
}

class AiChatException implements Exception {
  const AiChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeminiAiChatService implements AiChatService {
  GeminiAiChatService({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.client;

  static const _maxHistoryMessages = 12;

  final SupabaseClient _client;

  @override
  Future<String> send(List<AiChatMessage> messages) async {
    final accessToken = _client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AiChatException(
        'Melde dich an, um den KI-Assistenten zu nutzen.',
      );
    }

    final history = messages.length <= _maxHistoryMessages
        ? messages
        : messages.sublist(messages.length - _maxHistoryMessages);

    try {
      final response = await _client.functions.invoke(
        'gemini-chat',
        headers: {'Authorization': 'Bearer $accessToken'},
        body: {
          'messages': history.map((message) => message.toJson()).toList(),
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw const AiChatException('Gemini hat eine ungültige Antwort geliefert.');
      }
      final answer = data['answer'];
      if (answer is! String || answer.trim().isEmpty) {
        throw const AiChatException('Gemini hat keinen Antworttext geliefert.');
      }
      return answer.trim();
    } on FunctionException catch (error) {
      final details = error.details;
      final serverMessage =
          details is Map ? details['error']?.toString().trim() : null;
      if (error.status == 401) {
        throw const AiChatException(
          'Die Sitzung ist abgelaufen. Melde dich erneut an.',
        );
      }
      if (error.status == 429) {
        throw const AiChatException(
          'Das Gemini-Limit ist erreicht. Versuche es etwas später erneut.',
        );
      }
      throw AiChatException(
        serverMessage?.isNotEmpty == true
            ? serverMessage!
            : 'Die Antwort von Gemini ist fehlgeschlagen.',
      );
    }
  }
}
