import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/ai/models/ai_chat_message.dart';

void main() {
  test('Gemini history uses user and model roles', () {
    const user = AiChatMessage(
      role: AiChatRole.user,
      text: 'Что такое диез?',
    );
    const assistant = AiChatMessage(
      role: AiChatRole.model,
      text: 'Диез повышает ноту на полутон.',
    );

    expect(user.toJson(), {
      'role': 'user',
      'text': 'Что такое диез?',
    });
    expect(assistant.toJson(), {
      'role': 'model',
      'text': 'Диез повышает ноту на полутон.',
    });
  });
}
