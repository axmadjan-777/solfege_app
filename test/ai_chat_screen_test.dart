import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/ai/models/ai_chat_message.dart';
import 'package:solfege_app/features/ai/screens/ai_chat_screen.dart';
import 'package:solfege_app/features/ai/services/ai_chat_history.dart';
import 'package:solfege_app/features/ai/services/ai_chat_service.dart';
import 'package:solfege_app/features/ai/thinking_lines.dart';

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
    expect(find.text('Запрос не дошёл. Проверьте подключение и повторите.'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Что такое бемоль?'), findsOneWidget);
  });

  testWidgets('waiting for Gemini shows a musical line instead of a spinner', (
    tester,
  ) async {
    final gate = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        home: AiChatScreen(
          chatService: _GateService(gate.future),
          history: MemoryAiChatHistory(),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('ai_chat_input')), 'Что такое такт?');
    await tester.tap(find.byKey(const Key('ai_chat_send')));
    await tester.pump();

    expect(find.text(thinkingPhrases.first), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.text(thinkingPhrases[1]), findsOneWidget);

    gate.complete('Такт — группа долей.');
    await tester.pumpAndSettle();
    expect(find.text('Такт — группа долей.'), findsOneWidget);
    expect(find.text(thinkingPhrases[1]), findsNothing);
  });

  testWidgets('saved history appears and a new exchange is stored', (tester) async {
    final history = MemoryAiChatHistory(
      seed: const [
        AiChatMessage(role: AiChatRole.user, text: 'Что такое диез?'),
        AiChatMessage(role: AiChatRole.model, text: 'Диез повышает на полутон.'),
      ],
    );
    final service = _FakeAiChatService();
    await tester.pumpWidget(
      MaterialApp(home: AiChatScreen(chatService: service, history: history)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Что такое диез?'), findsOneWidget);
    expect(find.text('Диез повышает на полутон.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('ai_chat_input')), 'А бемоль?');
    await tester.tap(find.byKey(const Key('ai_chat_send')));
    await tester.pumpAndSettle();

    expect(find.text('А бемоль?'), findsOneWidget);
    expect(history.load(), completion(hasLength(4)));
    final saved = await history.load();
    expect(saved[2].role, AiChatRole.user);
    expect(saved[3].role, AiChatRole.model);
    expect(saved.every((message) => message.stored), isTrue);
  });

  testWidgets('a broken history load can be refreshed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AiChatScreen(
          chatService: _FakeAiChatService(),
          history: _BrokenHistory(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось открыть прошлые сообщения.'), findsOneWidget);
    expect(find.text('Обновить'), findsOneWidget);
  });
}

class _GateService implements AiChatService {
  _GateService(this.pending);

  final Future<String> pending;

  @override
  Future<String> send(List<AiChatMessage> messages) => pending;
}

class _BrokenHistory implements AiChatHistory {
  @override
  Future<AiChatMessage> append(AiChatMessage message) async => message;

  @override
  Future<List<AiChatMessage>> load() async {
    throw const AiChatHistoryException('Не удалось открыть прошлые сообщения.');
  }
}
