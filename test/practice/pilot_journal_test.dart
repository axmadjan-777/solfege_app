import 'package:solfege_app/features/practice/progress/pilot_journal.dart';
import 'package:test/test.dart';

void main() {
  final start = DateTime.utc(2026, 10, 1);
  final rows = [
    PilotRow(
      at: start,
      competencyId: 'not.read_treble_c4_g4',
      lessonId: 'L03-04',
      stage: 1,
      itemSignature: 'note-a',
      isCorrect: false,
      responseMs: 1000,
      hintsUsed: 1,
      errorTag: 'degree.4-vs-6',
      noteReading: true,
      device: 'phone',
      headphones: false,
      latencyBucket: 'fast',
    ),
    PilotRow(
      at: start.add(const Duration(days: 1)),
      competencyId: 'not.read_treble_c4_g4',
      lessonId: 'L03-04',
      stage: 1,
      itemSignature: 'note-a',
      isCorrect: false,
      responseMs: 3000,
      replays: 2,
      errorTag: 'degree.4-vs-6',
      noteReading: true,
      device: 'phone',
      headphones: true,
      latencyBucket: 'slow',
    ),
    PilotRow(
      at: start.add(const Duration(days: 7)),
      competencyId: 'sca.tonic',
      lessonId: 'L04-04',
      stage: 2,
      isCorrect: true,
      checkpoint: true,
      mix: true,
      dailyGoal: true,
      errorTag: 'degree.4-vs-6',
      device: 'tablet',
      latencyBucket: 'fast',
    ),
    PilotRow(
      at: start.add(const Duration(days: 8)),
      competencyId: 'sca.tonic',
      lessonId: 'L04-11',
      stage: 3,
      isCorrect: true,
      exam: true,
      transfer: true,
      device: 'tablet',
      latencyBucket: 'fast',
    ),
    PilotRow(
      at: start.add(const Duration(days: 30)),
      competencyId: 'ear.degree.major.1',
      lessonId: 'L04-11',
      stage: 8,
      isCorrect: true,
      errorTag: 'degree.4-vs-6',
      coldReview: true,
      device: 'phone',
      latencyBucket: 'slow',
    ),
  ];

  test('the pilot journal records every part-15 event from a fixed clock', () {
    final report = PilotReport.fromRows(rows: rows, masteredCompetencies: 1, competencyCount: 4);

    expect(report.activated, isTrue);
    expect(report.masteredShare, 0.25);
    expect(report.firstDelayedCheckPassed, isTrue);
    expect(report.checkpointFirstTry, isTrue);
    expect(report.examFirstTry, isTrue);
    expect(report.transferScore, 1);
    expect(report.errorRepeatedAt1, isTrue);
    expect(report.errorRepeatedAt7, isTrue);
    expect(report.errorRepeatedAt30, isTrue);
    expect(report.medianNoteReadingMs, 2000);
    expect(report.returnedOnD1, isTrue);
    expect(report.returnedOnD7, isTrue);
    expect(report.returnedOnD30, isTrue);
    expect(report.dailyGoalShare, 0.2);
    expect(report.mixShare, 0.2);
    expect(report.streak, 1);
    expect(report.dropOffLesson, 'L03-04');
    expect(report.dropOffStage, 1);
    expect(report.hintShare, 0.2);
    expect(report.replayShare, 0.2);
    expect(report.itemsUnderHalf, ['note-a']);
    expect(report.byDevice, {'phone': 3, 'tablet': 2});
    expect(report.byHeadphones, {'speaker': 4, 'headphones': 1});
    expect(report.byLatency, {'fast': 3, 'slow': 2});
  });
}
