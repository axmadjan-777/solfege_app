import 'json_reader.dart';
import 'mvp_status.dart';

/// Граф интервального повторения (`levels.json` → `config.review_policies`).
class ReviewPolicy {
  const ReviewPolicy({
    required this.id,
    required this.title,
    required this.firstDelayHours,
    required this.firstDelayRangeHours,
    required this.intervalDays,
    required this.desiredRetention,
  });

  factory ReviewPolicy.fromJson(JsonReader r) {
    final range = r.optInts('first_delay_range_hours');
    return ReviewPolicy(
      id: r.string('id'),
      title: r.string('title'),
      firstDelayHours: r.integer('first_delay_hours'),
      firstDelayRangeHours: range.length == 2 ? (range[0], range[1]) : (20, 48),
      intervalDays: r.optInts('interval_days'),
      desiredRetention: r.number('desired_retention'),
    );
  }

  final String id;
  final String title;
  final int firstDelayHours;
  final (int, int) firstDelayRangeHours;
  final List<int> intervalDays;
  final double desiredRetention;
}

/// Пороги владения (`config.mastery_rules`), все значения меняются без правки кода.
class MasteryRules {
  const MasteryRules({
    required this.statuses,
    required this.immediateMinAccuracy,
    required this.immediateWindow,
    required this.immediateMaxCriticalErrors,
    required this.delayedMinAccuracy,
    required this.delayedMinItems,
    required this.transferMinAccuracy,
    required this.transferDimensions,
    required this.demotionWindow,
    required this.demotionAccuracyBelow,
  });

  factory MasteryRules.fromJson(JsonReader r) {
    final immediate = r.object('immediate');
    final delayed = r.object('delayed');
    final transfer = r.object('transfer');
    final demotion = r.object('demotion_default');
    return MasteryRules(
      statuses: r.strings('statuses'),
      immediateMinAccuracy: immediate.number('min_accuracy'),
      immediateWindow: immediate.integer('window_items'),
      immediateMaxCriticalErrors: immediate.integer('max_critical_errors'),
      delayedMinAccuracy: delayed.number('min_accuracy'),
      delayedMinItems: delayed.integer('min_items'),
      transferMinAccuracy: transfer.number('min_accuracy'),
      transferDimensions: transfer.strings('dimensions'),
      demotionWindow: demotion.integer('window'),
      demotionAccuracyBelow: demotion.number('accuracy_below'),
    );
  }

  final List<String> statuses;
  final double immediateMinAccuracy;
  final int immediateWindow;
  final int immediateMaxCriticalErrors;
  final double delayedMinAccuracy;
  final int delayedMinItems;
  final double transferMinAccuracy;
  final List<String> transferDimensions;
  final int demotionWindow;
  final double demotionAccuracyBelow;
}

class CurriculumConfig {
  const CurriculumConfig({
    required this.masteryRules,
    required this.reviewPolicies,
    required this.raw,
  });

  factory CurriculumConfig.fromJson(JsonReader r) {
    return CurriculumConfig(
      masteryRules: MasteryRules.fromJson(r.object('mastery_rules')),
      reviewPolicies: [for (final p in r.objects('review_policies')) ReviewPolicy.fromJson(p)],
      raw: r.json,
    );
  }

  final MasteryRules masteryRules;
  final List<ReviewPolicy> reviewPolicies;

  /// daily_mix, error_queue, checkpoints, level_exam, diagnostic, skip_challenge —
  /// пока читаются напрямую; типизируются в фазах, где используются.
  final Map<String, dynamic> raw;

  ReviewPolicy policy(String id) => reviewPolicies.firstWhere(
        (p) => p.id == id,
        orElse: () => throw ArgumentError.value(id, 'review_policy_id'),
      );
}

class Level {
  const Level({
    required this.id,
    required this.number,
    required this.title,
    required this.goal,
    required this.prerequisites,
    required this.lessonCount,
    required this.examId,
    required this.mvpStatus,
    required this.stage,
  });

  factory Level.fromJson(JsonReader r) {
    return Level(
      id: r.string('id'),
      number: r.integer('number'),
      title: r.string('title'),
      goal: r.string('goal'),
      prerequisites: r.strings('prerequisites'),
      lessonCount: r.integer('lesson_count'),
      examId: r.string('exam_id'),
      mvpStatus: MvpStatus.parse(r.string('mvp_status')),
      stage: r.string('stage'),
    );
  }

  final String id;
  final int number;
  final String title;
  final String goal;
  final List<String> prerequisites;
  final int lessonCount;
  final String examId;
  final MvpStatus mvpStatus;
  final String stage;
}

class SourceRef {
  const SourceRef({required this.id, required this.title, required this.reliability});

  factory SourceRef.fromJson(JsonReader r) => SourceRef(
        id: r.string('id'),
        title: r.string('title'),
        reliability: r.optString('reliability') ?? '',
      );

  final String id;
  final String title;
  final String reliability;
}

class AudioItem {
  const AudioItem({
    required this.id,
    required this.kind,
    required this.purpose,
    required this.usedBy,
    required this.mvpStatus,
    required this.license,
    this.instrument,
    this.midiLow,
    this.midiHigh,
  });

  factory AudioItem.fromJson(JsonReader r) => AudioItem(
        id: r.string('id'),
        kind: r.string('kind'),
        purpose: r.string('purpose'),
        usedBy: r.strings('used_by'),
        mvpStatus: MvpStatus.parse(r.string('mvp_status')),
        license: r.string('license'),
        instrument: r.optString('instrument'),
        midiLow: r.optInt('midi_low'),
        midiHigh: r.optInt('midi_high'),
      );

  final String id;
  final String kind;
  final String purpose;
  final List<String> usedBy;
  final MvpStatus mvpStatus;
  final String license;
  final String? instrument;
  final int? midiLow;
  final int? midiHigh;
}
