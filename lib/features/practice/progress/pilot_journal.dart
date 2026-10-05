/// Строка локального журнала. Отдельной серверной таблицы нет.
class PilotRow {
  const PilotRow({
    required this.at,
    required this.competencyId,
    this.lessonId = '',
    this.stage = 0,
    this.itemSignature = '',
    this.isCorrect = true,
    this.responseMs = 0,
    this.hintsUsed = 0,
    this.replays = 0,
    this.errorTag = '',
    this.coldReview = false,
    this.checkpoint = false,
    this.exam = false,
    this.transfer = false,
    this.mix = false,
    this.dailyGoal = false,
    this.noteReading = false,
    this.device = '',
    this.headphones = false,
    this.latencyBucket = '',
  });

  final DateTime at;
  final String competencyId;
  final String lessonId;
  final int stage;
  final String itemSignature;
  final bool isCorrect;
  final int responseMs;
  final int hintsUsed;
  final int replays;
  final String errorTag;
  final bool coldReview;
  final bool checkpoint;
  final bool exam;
  final bool transfer;
  final bool mix;
  final bool dailyGoal;
  final bool noteReading;
  final String device;
  final bool headphones;
  final String latencyBucket;
}

class PilotReport {
  const PilotReport({
    required this.activated,
    required this.masteredShare,
    required this.firstDelayedCheckPassed,
    required this.checkpointFirstTry,
    required this.examFirstTry,
    required this.transferScore,
    required this.errorRepeatedAt1,
    required this.errorRepeatedAt7,
    required this.errorRepeatedAt30,
    required this.medianNoteReadingMs,
    required this.returnedOnD1,
    required this.returnedOnD7,
    required this.returnedOnD30,
    required this.dailyGoalShare,
    required this.mixShare,
    required this.streak,
    required this.dropOffLesson,
    required this.dropOffStage,
    required this.hintShare,
    required this.replayShare,
    required this.itemsUnderHalf,
    required this.byDevice,
    required this.byHeadphones,
    required this.byLatency,
  });

  final bool activated;
  final double masteredShare;
  final bool firstDelayedCheckPassed;
  final bool checkpointFirstTry;
  final bool examFirstTry;
  final double transferScore;
  final bool errorRepeatedAt1;
  final bool errorRepeatedAt7;
  final bool errorRepeatedAt30;
  final int medianNoteReadingMs;
  final bool returnedOnD1;
  final bool returnedOnD7;
  final bool returnedOnD30;
  final double dailyGoalShare;
  final double mixShare;
  final int streak;
  final String dropOffLesson;
  final int dropOffStage;
  final double hintShare;
  final double replayShare;
  final List<String> itemsUnderHalf;
  final Map<String, int> byDevice;
  final Map<String, int> byHeadphones;
  final Map<String, int> byLatency;

  factory PilotReport.fromRows({
    required List<PilotRow> rows,
    required int masteredCompetencies,
    required int competencyCount,
  }) {
    final ordered = [...rows]..sort((a, b) => a.at.compareTo(b.at));
    final first = ordered.isEmpty ? null : _day(ordered.first.at);
    final days = ordered.map((row) => _day(row.at)).toSet();
    bool onDay(int offset) => first != null && days.contains(first.add(Duration(days: offset)));
    final tagged = ordered.where((row) => row.errorTag.isNotEmpty).toList();
    final firstTag = tagged.isEmpty ? null : tagged.first;
    bool tagAgain(int offset) {
      if (firstTag == null) return false;
      final target = _day(firstTag.at).add(Duration(days: offset));
      return tagged.any((row) => row.errorTag == firstTag.errorTag && _day(row.at) == target);
    }

    final reading = ordered.where((row) => row.noteReading).map((row) => row.responseMs).toList()..sort();
    final transfers = ordered.where((row) => row.transfer).toList();
    final checkpoints = ordered.where((row) => row.checkpoint).toList();
    final exams = ordered.where((row) => row.exam).toList();
    final cold = ordered.where((row) => row.coldReview).toList();
    final byItem = <String, List<bool>>{};
    for (final row in ordered.where((row) => row.itemSignature.isNotEmpty)) {
      byItem.putIfAbsent(row.itemSignature, () => []).add(row.isCorrect);
    }
    final lastMiss = ordered.lastWhere((row) => !row.isCorrect, orElse: () => ordered.last);

    return PilotReport(
      activated: ordered.isNotEmpty,
      masteredShare: competencyCount == 0 ? 0 : masteredCompetencies / competencyCount,
      firstDelayedCheckPassed: cold.isNotEmpty && cold.first.isCorrect,
      checkpointFirstTry: checkpoints.isNotEmpty && checkpoints.first.isCorrect,
      examFirstTry: exams.isNotEmpty && exams.first.isCorrect,
      transferScore: transfers.isEmpty ? 0 : transfers.where((row) => row.isCorrect).length / transfers.length,
      errorRepeatedAt1: tagAgain(1),
      errorRepeatedAt7: tagAgain(7),
      errorRepeatedAt30: tagAgain(30),
      medianNoteReadingMs: _median(reading),
      returnedOnD1: onDay(1),
      returnedOnD7: onDay(7),
      returnedOnD30: onDay(30),
      dailyGoalShare: days.isEmpty ? 0 : ordered.where((row) => row.dailyGoal).map((row) => _day(row.at)).toSet().length / days.length,
      mixShare: ordered.isEmpty ? 0 : ordered.where((row) => row.mix).length / ordered.length,
      streak: _streak(days),
      dropOffLesson: ordered.isEmpty ? '' : lastMiss.lessonId,
      dropOffStage: ordered.isEmpty ? 0 : lastMiss.stage,
      hintShare: ordered.isEmpty ? 0 : ordered.where((row) => row.hintsUsed > 0).length / ordered.length,
      replayShare: ordered.isEmpty ? 0 : ordered.where((row) => row.replays > 0).length / ordered.length,
      itemsUnderHalf: [
        for (final entry in byItem.entries)
          if (entry.value.where((correct) => correct).length / entry.value.length < 0.5) entry.key,
      ],
      byDevice: _count(ordered.map((row) => row.device)),
      byHeadphones: _count(ordered.map((row) => row.headphones ? 'headphones' : 'speaker')),
      byLatency: _count(ordered.map((row) => row.latencyBucket)),
    );
  }
}

DateTime _day(DateTime at) => DateTime.utc(at.year, at.month, at.day);

int _median(List<int> sorted) {
  if (sorted.isEmpty) return 0;
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return ((sorted[mid - 1] + sorted[mid]) / 2).round();
}

int _streak(Set<DateTime> days) {
  if (days.isEmpty) return 0;
  final ordered = days.toList()..sort();
  var streak = 1;
  for (var i = ordered.length - 1; i > 0; i--) {
    if (ordered[i].difference(ordered[i - 1]).inDays == 1) {
      streak += 1;
    } else {
      break;
    }
  }
  return streak;
}

Map<String, int> _count(Iterable<String> values) {
  final counts = <String, int>{};
  for (final value in values) {
    if (value.isEmpty) continue;
    counts[value] = (counts[value] ?? 0) + 1;
  }
  return counts;
}
