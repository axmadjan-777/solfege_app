/// Возврат ошибки: после повтора в той же сессии срок — через сутки.
class ScheduledReturn {
  const ScheduledReturn({required this.tag, required this.dueAt});

  final String tag;
  final DateTime dueAt;

  Map<String, Object?> toJson() => {
        'tag': tag,
        'due_at': dueAt.toIso8601String(),
      };

  factory ScheduledReturn.fromJson(Map<String, dynamic> json) {
    return ScheduledReturn(
      tag: json['tag'] as String,
      dueAt: DateTime.parse(json['due_at'] as String),
    );
  }
}

/// Новый срок той же метки заменяет прежний.
List<ScheduledReturn> scheduleNextDay({
  required List<ScheduledReturn> current,
  required String tag,
  required DateTime at,
}) {
  if (tag.isEmpty) return current;
  final dueAt = at.add(const Duration(days: 1));
  return [
    for (final item in current)
      if (item.tag != tag) item,
    ScheduledReturn(tag: tag, dueAt: dueAt),
  ];
}

/// Метка должная, когда срок уже наступил, включая саму минуту.
List<String> dueReturnTags({
  required List<ScheduledReturn> scheduled,
  required DateTime now,
}) {
  return [
    for (final item in scheduled)
      if (!now.isBefore(item.dueAt)) item.tag,
  ];
}
