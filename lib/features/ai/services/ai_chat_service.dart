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
        'Войдите в аккаунт, чтобы пользоваться ИИ-ассистентом.',
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
        throw const AiChatException('Gemini вернул некорректный ответ.');
      }
      final answer = data['answer'];
      if (answer is! String || answer.trim().isEmpty) {
        throw const AiChatException('Gemini не вернул текст ответа.');
      }
      return answer.trim();
    } on FunctionException catch (error) {
      final details = error.details;
      final serverMessage =
          details is Map ? details['error']?.toString().trim() : null;
      if (error.status == 401) {
        throw const AiChatException(
          'Сессия истекла. Войдите в аккаунт снова.',
        );
      }
      if (error.status == 429) {
        throw const AiChatException(
          'Достигнут лимит Gemini. Попробуйте немного позже.',
        );
      }
      throw AiChatException(
        serverMessage?.isNotEmpty == true
            ? serverMessage!
            : 'Не удалось получить ответ Gemini.',
      );
    }
  }
}
