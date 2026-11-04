import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/ai_chat_message.dart';
import '../services/ai_chat_history.dart';
import '../services/ai_chat_service.dart';
import '../thinking_lines.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, this.chatService, this.history});

  final AiChatService? chatService;
  final AiChatHistory? history;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const _maxMessageLength = 2000;

  late final AiChatService _chatService =
      widget.chatService ?? GeminiAiChatService();
  late final AiChatHistory _history =
      widget.history ?? SupabaseAiChatHistory();
  final _messages = <AiChatMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isLoading = false;
  bool _loadingHistory = true;
  String? _errorDetails;
  String? _historyWarning;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final saved = await _history.load();
      if (!mounted) return;
      setState(() {
        if (_messages.isEmpty) {
          _messages.addAll(saved);
        } else {
          _messages.insertAll(0, saved);
        }
        _loadingHistory = false;
        _historyWarning = null;
      });
    } on AiChatHistoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
        _historyWarning = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
        _historyWarning = 'Не удалось открыть прошлые сообщения.';
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _inputController.text.trim();
    if (_isLoading || question.isEmpty) return;
    if (question.length > _maxMessageLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Вопрос должен быть короче 2000 символов.'),
        ),
      );
      return;
    }

    setState(() {
      _messages.add(
        AiChatMessage(role: AiChatRole.user, text: question),
      );
      _inputController.clear();
      _errorDetails = null;
    });
    _scrollToEnd();
    await _requestAnswer();
  }

  Future<void> _remember(AiChatMessage message) async {
    if (message.stored) return;
    try {
      final stored = await _history.append(message);
      if (!mounted) return;
      final index = _messages.indexOf(message);
      if (index < 0) return;
      setState(() => _messages[index] = stored);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _historyWarning = 'Сообщение осталось только на этом экране.',
      );
    }
  }

  Future<void> _requestAnswer() async {
    if (_isLoading || _messages.isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorDetails = null;
    });
    _scrollToEnd();

    await _remember(_messages.last);
    try {
      final answer = await _chatService.send(List.unmodifiable(_messages));
      if (!mounted) return;
      final reply = AiChatMessage(role: AiChatRole.model, text: answer);
      setState(() => _messages.add(reply));
      await _remember(reply);
    } on AiChatException catch (error) {
      if (!mounted) return;
      setState(() => _errorDetails = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorDetails = 'Запрос не дошёл. Проверьте подключение и повторите.',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (_historyWarning != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Row(
                  children: [
                    Expanded(child: Text(_historyWarning!)),
                    TextButton(
                      onPressed: _loadHistory,
                      child: const Text('Обновить'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _loadingHistory
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Листаю старые ноты'),
                      ),
                    )
                  : _messages.isEmpty
                      ? const _EmptyChat()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          itemCount: _messages.length +
                              (_isLoading ? 1 : 0) +
                              (_errorDetails != null ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < _messages.length) {
                              return _MessageBubble(message: _messages[index]);
                            }
                            if (_isLoading) return const ThinkingBubble();
                            return _ErrorBubble(
                              details: _errorDetails!,
                              onRetry: _requestAnswer,
                            );
                          },
                        ),
            ),
            _buildComposer(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.coral,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Музыкальный ИИ',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Спросите о теории музыки, сольфеджио, гармонии или практике.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('ai_chat_input'),
              controller: _inputController,
              minLines: 1,
              maxLines: 4,
              maxLength: _maxMessageLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Задайте вопрос о музыке…',
                counterText: '',
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            key: const Key('ai_chat_send'),
            onPressed: _isLoading ? null : _send,
            tooltip: 'Отправить',
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.music_note_rounded,
              size: 44,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Например: «Чем диез отличается от бемоля?»',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Ассистент отвечает только на музыкальные вопросы.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AiChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.coral : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: SelectableText(
          message.text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isUser ? AppColors.textOnAccent : AppColors.textPrimary,
              ),
        ),
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({
    required this.details,
    required this.onRetry,
  });

  final String details;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Не удалось получить ответ',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(details, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              TextButton(onPressed: onRetry, child: const Text('Повторить')),
            ],
          ),
        ),
      ),
    );
  }
}
