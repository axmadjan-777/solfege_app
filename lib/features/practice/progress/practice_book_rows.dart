import 'progress_store.dart';

Map<String, dynamic> practiceBookPayload({
  required String userId,
  required ProgressBook book,
  required DateTime at,
}) {
  return {
    'user_id': userId,
    'book': book.toJson(),
    'updated_at': at.toUtc().toIso8601String(),
  };
}

List<Map<String, dynamic>> practiceAttemptRows({
  required String userId,
  required ProgressBook book,
}) {
  return [
    for (final attempt in book.attempts)
      {
        'user_id': userId,
        'competency_id': attempt.competencyId,
        'session_id': attempt.sessionId,
        'item_signature': attempt.itemSignature,
        'error_tag': attempt.errorTag,
        'is_correct': attempt.isCorrect,
        'response_ms': attempt.responseMs,
        'hints_used': attempt.hintsUsed,
        'replays': attempt.replays,
        'tonality': attempt.tonality,
        'critical': attempt.critical,
        'cold_review': attempt.coldReview,
        'transfer': attempt.transfer,
        'created_at': attempt.createdAt.toUtc().toIso8601String(),
      },
  ];
}

List<Map<String, dynamic>> practiceCompetencyRows({
  required String userId,
  required ProgressBook book,
  required DateTime at,
}) {
  return [
    for (final entry in book.competencies.entries)
      {
        'user_id': userId,
        'competency_id': entry.key,
        'status': entry.value.status.id,
        'interval_step': entry.value.intervalStep,
        'due_at': entry.value.dueAt?.toUtc().toIso8601String(),
        'provisional_at': entry.value.provisionalAt?.toUtc().toIso8601String(),
        'stability': [
          for (final session in entry.value.stability.sessions)
            session.toJson(),
        ],
        'updated_at': at.toUtc().toIso8601String(),
      },
  ];
}

List<Map<String, dynamic>> practiceReturnRows({
  required String userId,
  required ProgressBook book,
}) {
  return [
    for (final item in book.returns)
      {
        'user_id': userId,
        'tag': item.tag,
        'due_at': item.dueAt.toUtc().toIso8601String(),
      },
  ];
}

/// Пустая локальная книга уступает серверу. Иначе остаётся устройство.
bool adoptRemoteBook({
  required int localAttempts,
  required bool remoteExists,
}) {
  return remoteExists && localAttempts == 0;
}
