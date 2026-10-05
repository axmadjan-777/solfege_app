import '../progress/attempt.dart';

class AssessmentRules {
  const AssessmentRules({
    required this.examOverall,
    required this.examPerBlock,
    required this.diagnosticGrantsMastered,
    required this.diagnosticAxes,
    required this.skipMinItems,
    required this.skipMaxItems,
    required this.skipRepresentations,
    required this.skipNeedsTransfer,
    required this.skipPass,
    required this.checkpointItems,
    required this.checkpointHints,
    required this.checkpointPass,
  });

  factory AssessmentRules.fromConfig(Map<String, dynamic> config) {
    final exam = config['level_exam'] as Map;
    final diagnostic = config['diagnostic'] as Map;
    final skip = config['skip_challenge'] as Map;
    final checkpoint = config['checkpoints'] as Map;
    final skipItems = skip['items'] as List;
    return AssessmentRules(
      examOverall: (exam['pass_overall'] as num).toDouble(),
      examPerBlock: (exam['pass_per_block'] as num).toDouble(),
      diagnosticGrantsMastered: diagnostic['grants_mastered'] as bool,
      diagnosticAxes: [for (final axis in diagnostic['axes'] as List) axis as String],
      skipMinItems: (skipItems[0] as num).toInt(),
      skipMaxItems: (skipItems[1] as num).toInt(),
      skipRepresentations: (skip['representations_required'] as num).toInt(),
      skipNeedsTransfer: skip['transfer_required'] as bool,
      skipPass: (skip['pass'] as num).toDouble(),
      checkpointItems: (checkpoint['items'] as num).toInt(),
      checkpointHints: (checkpoint['hints_allowed'] as num).toInt(),
      checkpointPass: 0.8,
    );
  }

  final double examOverall;
  final double examPerBlock;
  final bool diagnosticGrantsMastered;
  final List<String> diagnosticAxes;
  final int skipMinItems;
  final int skipMaxItems;
  final int skipRepresentations;
  final bool skipNeedsTransfer;
  final double skipPass;
  final int checkpointItems;
  final int checkpointHints;

  /// В `checkpoints` JSON порога нет. 0.8 берётся из части 15.
  final double checkpointPass;

  bool examPassed({required double overall, required List<double> blocks}) {
    return overall >= examOverall && blocks.every((block) => block >= examPerBlock);
  }

  CompetencyStatus diagnosticStatus() => CompetencyStatus.practicing;

  bool skipPassed({
    required int items,
    required int representations,
    required bool transfer,
    required double accuracy,
  }) {
    return items >= skipMinItems &&
        items <= skipMaxItems &&
        representations >= skipRepresentations &&
        transfer == skipNeedsTransfer &&
        accuracy >= skipPass;
  }

  bool checkpointPassed(double accuracy) => accuracy >= checkpointPass;

  CompetencyStatus afterBrokenStreak(CompetencyStatus status) => status;
}
