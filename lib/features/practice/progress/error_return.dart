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
List<ScheduledReturn> scheduleAfter({
  required List<ScheduledReturn> current,
  required String tag,
  required DateTime at,
  required int days,
}) {
  if (tag.isEmpty || days <= 0) return current;
  final dueAt = at.add(Duration(days: days));
  return [
    for (final item in current)
      if (item.tag != tag) item,
    ScheduledReturn(tag: tag, dueAt: dueAt),
  ];
}

List<ScheduledReturn> scheduleNextDay({
  required List<ScheduledReturn> current,
  required String tag,
  required DateTime at,
}) {
  return scheduleAfter(current: current, tag: tag, at: at, days: 1);
}

/// `error_queue.after_success_days`, иначе трое суток.
int errorReturnSuccessDays(Map<String, dynamic> raw) {
  final queue = raw['error_queue'];
  final days = queue is Map ? queue['after_success_days'] : null;
  if (days is num && days > 0) return days.toInt();
  return 3;
}

String returnGapLabel(int days) {
  final mod10 = days % 10;
  final mod100 = days % 100;
  if (mod10 == 1 && mod100 != 11) return 'Через $days день';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'Через $days дня';
  }
  return 'Через $days дней';
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
