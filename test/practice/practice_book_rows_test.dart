import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/error_return.dart';
import 'package:solfege_app/features/practice/progress/practice_book_rows.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:test/test.dart';

void main() {
  test(
      'a miss becomes an attempt row and an empty device takes the server book',
      () {
    final at = DateTime.utc(2026, 10, 5, 8);
    final book = ProgressBook(
      userId: 'local',
      competencies: {
        'ear.interval.m3_M3': const CompetencySnapshot(
          status: CompetencyStatus.practicing,
          stability: Stability(),
          intervalStep: 0,
          dueAt: null,
          provisionalAt: null,
        ),
      },
      attempts: [
        AttemptRecord(
          competencyId: 'ear.interval.m3_M3',
          sessionId: 's',
          itemSignature: 'PR-03-0',
          errorTag: 'PR-03',
          competencyIds: ['ear.interval.m3_M3'],
          isCorrect: false,
          responseMs: 0,
          hintsUsed: 0,
          replays: 1,
          confidence: null,
          createdAt: DateTime.utc(2026, 10, 5, 8),
          tonality: 'C',
          critical: false,
          coldReview: false,
          transfer: false,
        ),
      ],
      returns: [
        ScheduledReturn(tag: 'PR-03', dueAt: DateTime.utc(2026, 10, 6, 8)),
      ],
    );

    final attempt = practiceAttemptRows(userId: 'user-1', book: book).single;
    expect(attempt['is_correct'], isFalse);
    expect(attempt['error_tag'], 'PR-03');
    expect(attempt['replays'], 1);
    expect(
      practiceCompetencyRows(userId: 'user-1', book: book, at: at)
          .single['status'],
      'practicing',
    );
    expect(
      practiceReturnRows(userId: 'user-1', book: book).single['tag'],
      'PR-03',
    );
    expect(practiceBookPayload(userId: 'user-1', book: book, at: at)['user_id'],
        'user-1');
    expect(adoptRemoteBook(localAttempts: 0, remoteExists: true), isTrue);
    expect(adoptRemoteBook(localAttempts: 2, remoteExists: true), isFalse);
  });
}
