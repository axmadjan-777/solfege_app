import 'json_reader.dart';
import 'mvp_status.dart';

/// Микро-компетенция — единица прогресса (`competencies.json`).
class Competency {
  const Competency({
    required this.id,
    required this.title,
    required this.skillTrack,
    required this.skillType,
    required this.appSection,
    required this.prerequisites,
    required this.firstLessonId,
    required this.practiceSetIds,
    required this.initialPassMinAccuracy,
    required this.initialPassMinItems,
    required this.coldReviewMinAccuracy,
    required this.coldReviewMinItems,
    required this.coldReviewPolicyId,
    required this.immediateThreshold,
    required this.delayedThreshold,
    required this.transferThreshold,
    required this.reviewPolicyId,
    required this.demotionWindow,
    required this.demotionAccuracyBelow,
    required this.levelExamId,
    required this.errorTags,
    required this.siblingIds,
    required this.mvpStatus,
  });

  factory Competency.fromJson(JsonReader r) {
    final initial = r.object('initial_pass');
    final cold = r.object('cold_review');
    final mastery = r.object('mastery_threshold');
    final demotion = r.object('demotion');
    return Competency(
      id: r.string('id'),
      title: r.string('title'),
      skillTrack: r.string('skill_track'),
      skillType: r.string('skill_type'),
      appSection: r.string('app_section'),
      prerequisites: r.strings('prerequisites'),
      firstLessonId: r.optString('first_lesson_id'),
      practiceSetIds: r.strings('practice_set_ids'),
      initialPassMinAccuracy: initial.number('min_accuracy'),
      initialPassMinItems: initial.integer('min_items'),
      coldReviewMinAccuracy: cold.number('min_accuracy'),
      coldReviewMinItems: cold.integer('min_items'),
      coldReviewPolicyId: cold.string('policy_id'),
      immediateThreshold: mastery.number('immediate'),
      delayedThreshold: mastery.number('delayed'),
      transferThreshold: mastery.number('transfer'),
      reviewPolicyId: r.string('review_policy_id'),
      demotionWindow: demotion.optInt('window'),
      demotionAccuracyBelow: demotion.optNumber('accuracy_below'),
      levelExamId: r.string('level_exam_id'),
      errorTags: r.optStrings('error_tags'),
      siblingIds: r.optStrings('sibling_ids'),
      mvpStatus: MvpStatus.parse(r.optString('mvp_status') ?? 'mvp'),
    );
  }

  final String id;
  final String title;
  final String skillTrack;
  final String skillType;
  final String appSection;
  final List<String> prerequisites;
  final String? firstLessonId;
  final List<String> practiceSetIds;
  final double initialPassMinAccuracy;
  final int initialPassMinItems;
  final double coldReviewMinAccuracy;
  final int coldReviewMinItems;
  final String coldReviewPolicyId;
  final double immediateThreshold;
  final double delayedThreshold;
  final double transferThreshold;
  final String reviewPolicyId;
  final int? demotionWindow;
  final double? demotionAccuracyBelow;
  final String levelExamId;
  final List<String> errorTags;
  final List<String> siblingIds;
  final MvpStatus mvpStatus;
}
