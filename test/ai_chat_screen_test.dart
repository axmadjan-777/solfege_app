import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/ai/models/ai_chat_message.dart';
import 'package:solfege_app/features/ai/screens/ai_chat_screen.dart';
import 'package:solfege_app/features/ai/services/ai_chat_service.dart';

class _FakeAiChatService implements AiChatService {
  _FakeAiChatService({this.error});

  final Object? error;
  List<AiChatMessage>? receivedMessages;

  @override
  Future<String> send(List<AiChatMessage> messages) async {
    receivedMessages = List.of(messages);
    if (error != null) throw error!;
    return 'До мажор: до, ре, ми, фа, соль, ля, си. '
        'Примеры: до–ми–соль; фа–ля–до; соль–си–ре.';
  }
}

void main() {
  testWidgets('user sends a music question and sees the Gemini response', (
    tester,
  ) async {
    final service = _FakeAiChatService();
    await tester.pumpWidget(
      MaterialApp(home: AiChatScreen(chatService: service)),
    );

    await tester.enterText(
      find.byKey(const Key('ai_chat_input')),
      'Какие ноты входят в до мажор?',
    );
    await tester.tap(find.byKey(const Key('ai_chat_send')));
    await tester.pumpAndSettle();

    expect(find.text('Какие ноты входят в до мажор?'), findsOneWidget);
    expect(find.textContaining('До мажор: до, ре, ми'), findsOneWidget);
    expect(service.receivedMessages, isNotNull);
    expect(service.receivedMessages!.last.role, AiChatRole.user);
  });

  testWidgets('failed request can be retried without duplicating the question',
      (
    tester,
  ) async {
    final service = _FakeAiChatService(error: Exception('offline'));
    await tester.pumpWidget(
      MaterialApp(home: AiChatScreen(chatService: service)),
    );

    await tester.enterText(
      find.byKey(const Key('ai_chat_input')),
      'Что такое бемоль?',
    );
    await tester.tap(find.byKey(const Key('ai_chat_send')));
    await tester.pumpAndSettle();

    expect(find.text('Что такое бемоль?'), findsOneWidget);
    expect(find.text('Не удалось получить ответ'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });
}
