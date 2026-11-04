import 'package:flutter/material.dart';

import '../progress/account_progress_store.dart';

/// Consent and recovery actions are product choices, not implicit migrations.
class AccountProgressNotice extends StatefulWidget {
  const AccountProgressNotice({super.key, required this.store});
  final AccountProgressStore store;
  @override
  State<AccountProgressNotice> createState() => _AccountProgressNoticeState();
}

class _AccountProgressNoticeState extends State<AccountProgressNotice> {
  bool _busy = false;

  Future<void> _action(Future<void> Function() action,
      {String? confirmation}) async {
    if (_busy || !widget.store.isActive) return;
    if (confirmation != null) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Выбор прогресса'),
                content: Text(confirmation),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Подтвердить'))
                ],
              ));
      if (confirmed != true || !mounted || !widget.store.isActive) return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Не удалось сохранить выбор. Прогресс не удалён. Повторите попытку.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final conflict = store.state == AccountSyncState.conflict ||
            store.state == AccountSyncState.legacyRemote;
        if (!store.hasLegacy &&
            !store.hasBackup &&
            !conflict &&
            store.state != AccountSyncState.error) {
          return const SizedBox.shrink();
        }
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (store.hasLegacy) ...[
                        const Text(
                            'На устройстве есть старый прогресс без надёжной привязки к аккаунту.'),
                        Wrap(children: [
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _action(store.importLegacy,
                                      confirmation:
                                          'Импортировать старый прогресс в этот аккаунт? Исходная копия останется на устройстве. Текущий прогресс сохранится в резерве.'),
                              child: const Text('Импортировать')),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _action(store.dismissLegacy),
                              child: const Text('Не импортировать')),
                        ]),
                      ],
                      if (store.message != null) Text(store.message!),
                      if (conflict)
                        Wrap(children: [
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _action(
                                      () => store.resolveConflict(
                                          useRemote: true),
                                      confirmation:
                                          'Использовать облачную копию в этом аккаунте? Копия устройства сохранится в резерве.'),
                              child: const Text('Облачная копия')),
                          TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _action(
                                      () => store.resolveConflict(
                                          useRemote: false),
                                      confirmation:
                                          'Отправить копию устройства? Предыдущая облачная версия сохранится в истории и в резерве устройства.'),
                              child: const Text('Копия устройства')),
                        ]),
                      if (store.state == AccountSyncState.error)
                        TextButton(
                            onPressed:
                                _busy ? null : () => _action(store.retrySync),
                            child: const Text('Повторить синхронизацию')),
                      if (store.hasBackup)
                        TextButton(
                            onPressed: _busy
                                ? null
                                : () => _action(store.restoreBackup,
                                    confirmation:
                                        'Восстановить последнюю резервную копию в этом аккаунте? Текущая копия тоже останется в резерве.'),
                            child: const Text('Резервная копия')),
                      if (_busy) const LinearProgressIndicator(),
                    ]),
              )),
        );
      });
}
