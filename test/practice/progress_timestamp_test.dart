import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/error_return.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';

void main() {
  test('local book timestamps serialize as UTC and restore the same instant',
      () {
    final local = DateTime(2026, 11, 5, 12, 34, 56);
    expect(local.isUtc, isFalse);
    final book = ProgressBook(userId: 'owner', competencies: {
      'skill': CompetencySnapshot(
          status: CompetencyStatus.mastered,
          stability:
              Stability(sessions: [StabilitySession(at: local, tonality: 'C')]),
          intervalStep: 1,
          dueAt: local,
          provisionalAt: local),
    }, attempts: [
      AttemptRecord(
          competencyId: 'skill',
          competencyIds: const ['skill', 'joint'],
          sessionId: 'session',
          itemSignature: 'item',
          errorTag: '',
          isCorrect: true,
          responseMs: 42,
          hintsUsed: 0,
          replays: 0,
          confidence: 0.5,
          createdAt: local,
          tonality: 'C',
          critical: false,
          coldReview: true,
          transfer: false)
    ], returns: [
      ScheduledReturn(tag: 'review', dueAt: local)
    ], passedStages: const {
      'PR-01': [4]
    });
    final json = jsonDecode(jsonEncode(book.toJson())) as Map<String, dynamic>;
    final snapshot = (json['competencies'] as Map)['skill'] as Map;
    final dates = <String>[
      (json['attempts'] as List).single['created_at'] as String,
      snapshot['due_at'] as String,
      snapshot['provisional_at'] as String,
      (snapshot['stability'] as List).single['at'] as String,
      (json['returns'] as List).single['due_at'] as String,
    ];
    expect(dates, everyElement(endsWith('Z')));
    final restored = ProgressBook.fromJson(json);
    final restoredSnapshot = restored.competencies['skill']!;
    for (final value in [
      restored.attempts.single.createdAt,
      restoredSnapshot.dueAt!,
      restoredSnapshot.provisionalAt!,
      restoredSnapshot.stability.sessions.single.at,
      restored.returns.single.dueAt
    ]) {
      expect(value.isUtc, isTrue);
      expect(value.isAtSameMomentAs(local), isTrue);
    }
    expect(restored.attempts.single.competencyIds, ['skill', 'joint']);
    expect(restored.attempts.single.responseMs, 42);
    expect(restored.passedStages, {
      'PR-01': [4]
    });
  });

  test(
      'legacy timestamps without offset keep the previous local interpretation',
      () {
    final old = AttemptRecord.fromJson({
      'competency_id': 'skill',
      'competency_ids': ['skill'],
      'session_id': 's',
      'item_signature': 'item',
      'error_tag': '',
      'is_correct': true,
      'response_ms': 0,
      'hints_used': 0,
      'replays': 0,
      'confidence': null,
      'created_at': '2026-11-05T12:34:56',
      'tonality': 'C',
      'critical': false,
      'cold_review': false,
      'transfer': false,
    });
    expect(old.createdAt.isUtc, isFalse);
    expect(old.createdAt.isAtSameMomentAs(DateTime(2026, 11, 5, 12, 34, 56)),
        isTrue);
    expect(old.toJson()['created_at'], endsWith('Z'));
  });
}
