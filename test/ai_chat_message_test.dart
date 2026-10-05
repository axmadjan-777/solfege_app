import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/ai/models/ai_chat_message.dart';
import 'package:solfege_app/features/ai/services/ai_chat_history.dart';

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

  test('a stored row becomes a message and a blank row is dropped', () {
    final message = messageFromRow({
      'id': 'm1',
      'role': 'user',
      'body': 'Что такое пауза?',
    });
    expect(message?.stored, isTrue);
    expect(message?.text, 'Что такое пауза?');
    expect(messageFromRow({'role': 'nope', 'body': 'x'}), isNull);
    expect(messageFromRow({'role': 'model', 'body': ''}), isNull);
  });
}
