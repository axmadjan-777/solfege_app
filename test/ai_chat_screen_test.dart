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
    expect(find.text('Запрос не дошёл. Проверьте подключение и повторите.'),
        findsOneWidget);

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

    await tester.enterText(
        find.byKey(const Key('ai_chat_input')), 'Что такое такт?');
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

  testWidgets('saved history appears and a new exchange is stored',
      (tester) async {
    final history = MemoryAiChatHistory(
      seed: const [
        AiChatMessage(role: AiChatRole.user, text: 'Что такое диез?'),
        AiChatMessage(
            role: AiChatRole.model, text: 'Диез повышает на полутон.'),
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

  testWidgets(
      'refresh keeps saved rows and unsaved exchange without duplicating either',
      (tester) async {
    final history = _FailingAppendHistory();
    await tester.pumpWidget(MaterialApp(
        home:
            AiChatScreen(chatService: _FakeAiChatService(), history: history)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('ai_chat_input')), 'Новый вопрос');
    await tester.tap(find.byKey(const Key('ai_chat_send')));
    await tester.pumpAndSettle();
    for (var index = 0; index < 2; index++) {
      await tester.tap(find.text('Обновить'));
      await tester.pumpAndSettle();
      expect(find.text('Сохранённый вопрос'), findsOneWidget);
      expect(find.text('Сохранённый ответ'), findsOneWidget);
      expect(find.text('Новый вопрос'), findsOneWidget);
      expect(find.textContaining('До мажор: до, ре, ми'), findsOneWidget);
    }
  });

  testWidgets(
      'send cannot append A text for B before the owner notification arrives',
      (tester) async {
    final history = _ScopedHistory();
    addTearDown(history.changes.close);
    final service = _FakeAiChatService();
    await tester.pumpWidget(MaterialApp(
        home: AiChatScreen(chatService: service, history: history)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('ai_chat_input')), 'Черновик аккаунта A');

    // The SDK session changes synchronously; its public event stream is async.
    history.owner = 'B';
    await tester.tap(find.byKey(const Key('ai_chat_send')));
    await tester.pumpAndSettle();
    expect(history.rows['B'], hasLength(1));
    expect(service.receivedMessages, isNull);

    history.changes.add('B');
    await tester.pumpAndSettle();
    expect(find.text('История B'), findsOneWidget);
    expect(find.text('Черновик аккаунта A'), findsNothing);
  });

  testWidgets(
      'retry cannot send A history for B before the owner notification arrives',
      (tester) async {
    final history = _ScopedHistory();
    addTearDown(history.changes.close);
    final service = _CountingFailedService();
    await tester.pumpWidget(MaterialApp(
        home: AiChatScreen(chatService: service, history: history)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('ai_chat_input')), 'Вопрос аккаунта A');
    await tester.tap(find.byKey(const Key('ai_chat_send')));
    await tester.pumpAndSettle();
    expect(service.calls, 1);

    history.owner = 'B';
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(history.rows['B'], hasLength(1));
    history.changes.add('B');
    await tester.pumpAndSettle();
    expect(find.text('Вопрос аккаунта A'), findsNothing);
  });

  testWidgets(
      'refresh reconciles a lost acknowledgement by ID and keeps only genuinely unsaved rows',
      (tester) async {
    final history = _LostAcknowledgementHistory();
    await tester.pumpWidget(MaterialApp(
        home:
            AiChatScreen(chatService: _FakeAiChatService(), history: history)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('ai_chat_input')),
        'Вопрос с потерянным подтверждением');
    await tester.tap(find.byKey(const Key('ai_chat_send')));
    await tester.pumpAndSettle();

    for (var index = 0; index < 2; index++) {
      await tester.tap(find.text('Обновить'));
      await tester.pumpAndSettle();
      expect(find.text('Вопрос с потерянным подтверждением'), findsOneWidget);
      expect(find.textContaining('До мажор: до, ре, ми'), findsOneWidget);
      expect(find.text('Сообщение осталось только на этом экране.'),
          findsOneWidget);
    }

    history.commitPendingAnswer();
    await tester.tap(find.text('Обновить'));
    await tester.pumpAndSettle();
    expect(find.text('Вопрос с потерянным подтверждением'), findsOneWidget);
    expect(find.textContaining('До мажор: до, ре, ми'), findsOneWidget);
    expect(
        find.text('Сообщение осталось только на этом экране.'), findsNothing);
    expect(find.text('Обновить'), findsNothing);
    expect(await history.load(), hasLength(2));
  });

  testWidgets(
      'switching account hides A messages and ignores a late Gemini reply',
      (tester) async {
    final history = _ScopedHistory();
    addTearDown(history.changes.close);
    final answer = Completer<String>();
    await tester.pumpWidget(MaterialApp(
        home: AiChatScreen(
            chatService: _GateService(answer.future), history: history)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('ai_chat_input')), 'Личный вопрос A');
    await tester.tap(find.byKey(const Key('ai_chat_send')));
    await tester.pump();
    history.switchTo('B');
    await tester.pumpAndSettle();
    expect(find.text('История B'), findsOneWidget);
    expect(find.text('Личный вопрос A'), findsNothing);
    answer.complete('Поздний ответ A');
    await tester.pumpAndSettle();
    expect(find.text('Поздний ответ A'), findsNothing);
    expect(history.rows['B'], hasLength(1));
  });

  testWidgets(
      'switching during save prevents sending old history under the new account',
      (tester) async {
    final history = _ScopedHistory()..appendGate = Completer<void>();
    addTearDown(history.changes.close);
    final service = _FakeAiChatService();
    await tester.pumpWidget(MaterialApp(
        home: AiChatScreen(chatService: service, history: history)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('ai_chat_input')), 'Вопрос до смены');
    await tester.tap(find.byKey(const Key('ai_chat_send')));
    await tester.pump();
    history.switchTo('B');
    history.appendGate!.complete();
    await tester.pumpAndSettle();
    expect(service.receivedMessages, isNull);
    expect(find.text('Вопрос до смены'), findsNothing);
    expect(find.text('История B'), findsOneWidget);
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

class _CountingFailedService implements AiChatService {
  int calls = 0;

  @override
  Future<String> send(List<AiChatMessage> messages) async {
    calls += 1;
    throw const AiChatException('offline');
  }
}

class _LostAcknowledgementHistory implements AiChatHistory {
  final _rows = <AiChatMessage>[];
  AiChatMessage? _pendingAnswer;

  @override
  Future<List<AiChatMessage>> load() async => List.of(_rows);

  @override
  Future<AiChatMessage> append(AiChatMessage message) async {
    if (message.role == AiChatRole.user) {
      _rows.add(message.markStored());
    } else {
      _pendingAnswer = message;
    }
    throw const AiChatHistoryException('acknowledgement lost');
  }

  void commitPendingAnswer() {
    _rows.add(_pendingAnswer!.markStored());
  }
}

class _BrokenHistory implements AiChatHistory {
  @override
  Future<AiChatMessage> append(AiChatMessage message) async => message;

  @override
  Future<List<AiChatMessage>> load() async {
    throw const AiChatHistoryException('Не удалось открыть прошлые сообщения.');
  }
}

class _FailingAppendHistory implements AiChatHistory {
  @override
  Future<List<AiChatMessage>> load() async => const [
        AiChatMessage(
            role: AiChatRole.user, text: 'Сохранённый вопрос', stored: true),
        AiChatMessage(
            role: AiChatRole.model, text: 'Сохранённый ответ', stored: true),
      ];
  @override
  Future<AiChatMessage> append(AiChatMessage message) async =>
      throw const AiChatHistoryException('offline');
}

class _ScopedHistory implements AccountScopedAiChatHistory {
  final changes = StreamController<String?>.broadcast(sync: true);
  var owner = 'A';
  Completer<void>? appendGate;
  final rows = <String, List<AiChatMessage>>{
    'A': [
      const AiChatMessage(
          role: AiChatRole.model, text: 'История A', stored: true)
    ],
    'B': [
      const AiChatMessage(
          role: AiChatRole.model, text: 'История B', stored: true)
    ],
  };
  void switchTo(String next) {
    owner = next;
    changes.add(next);
  }

  @override
  String get currentOwnerId => owner;
  @override
  Stream<String?> get ownerChanges => changes.stream;
  @override
  Future<List<AiChatMessage>> load() async => List.of(rows[owner]!);
  @override
  Future<AiChatMessage> append(AiChatMessage message) async {
    final target = owner;
    await appendGate?.future;
    final saved = message.markStored();
    rows[target]!.add(saved);
    return saved;
  }
}
