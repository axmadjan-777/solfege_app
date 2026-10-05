import 'json_reader.dart';
import 'mvp_status.dart';

/// Урок раздела «Теория» (`lessons.json`).
class Lesson {
  const Lesson({
    required this.id,
    required this.appSection,
    required this.skillTrack,
    required this.level,
    required this.order,
    required this.title,
    required this.goal,
    required this.primaryCompetency,
    required this.supportingCompetencies,
    required this.competencyIds,
    required this.prerequisites,
    required this.plainExplanation,
    required this.newTerms,
    required this.visual,
    required this.userAction,
    required this.interactionTemplate,
    required this.exerciseParams,
    required this.audio,
    required this.feedbackCorrect,
    required this.feedbackFirstError,
    required this.feedbackRepeatError,
    required this.learningItems,
    required this.checkItems,
    required this.passCriterion,
    required this.practiceSetIds,
    required this.reviewTopics,
    required this.finalTask,
    required this.reviewRule,
    required this.coldReviewPolicyId,
    required this.mvpStatus,
    required this.teacherReviewStatus,
    required this.manualContentNeeded,
    required this.sources,
    required this.raw,
  });

  factory Lesson.fromJson(JsonReader r) {
    return Lesson(
      id: r.string('id'),
      appSection: r.string('app_section'),
      skillTrack: r.string('skill_track'),
      level: r.integer('level'),
      order: r.integer('order'),
      title: r.string('title'),
      goal: r.string('goal'),
      primaryCompetency: r.string('primary_competency'),
      supportingCompetencies: r.strings('supporting_competencies'),
      competencyIds: r.strings('competency_ids'),
      prerequisites: [
        for (final p in r.strings('prerequisite_ids')) PrerequisiteRef.parse(p),
      ],
      plainExplanation: r.string('plain_explanation'),
      newTerms: r.strings('new_terms'),
      visual: r.string('visual'),
      userAction: r.string('user_action'),
      interactionTemplate: r.string('interaction_template'),
      exerciseParams: r.object('exercise_params').json,
      audio: r.object('audio').json,
      feedbackCorrect: r.string('feedback_correct'),
      feedbackFirstError: r.string('feedback_first_error'),
      feedbackRepeatError: r.string('feedback_repeat_error'),
      learningItems: r.integer('learning_items'),
      checkItems: r.integer('check_items'),
      passCriterion: r.string('pass_criterion'),
      practiceSetIds: r.strings('practice_set_ids'),
      reviewTopics: r.strings('review_topics'),
      finalTask: r.string('final_task'),
      reviewRule: r.string('review_rule'),
      coldReviewPolicyId: r.object('cold_review').string('policy_id'),
      mvpStatus: MvpStatus.parse(r.string('mvp_status')),
      teacherReviewStatus: r.string('teacher_review_status'),
      manualContentNeeded: r.optBool('manual_content_needed') ?? false,
      sources: r.strings('sources'),
      raw: r.json,
    );
  }

  final String id;
  final String appSection;
  final String skillTrack;
  final int level;
  final int order;
  final String title;
  final String goal;
  final String primaryCompetency;
  final List<String> supportingCompetencies;
  final List<String> competencyIds;
  final List<PrerequisiteRef> prerequisites;
  final String plainExplanation;
  final List<String> newTerms;
  final String visual;
  final String userAction;
  final String interactionTemplate;
  final Map<String, dynamic> exerciseParams;
  final Map<String, dynamic> audio;
  final String feedbackCorrect;
  final String feedbackFirstError;
  final String feedbackRepeatError;
  final int learningItems;
  final int checkItems;
  final String passCriterion;
  final List<String> practiceSetIds;
  final List<String> reviewTopics;
  final String finalTask;
  final String reviewRule;
  final String coldReviewPolicyId;
  final MvpStatus mvpStatus;
  final String teacherReviewStatus;
  final bool manualContentNeeded;
  final List<String> sources;
  final Map<String, dynamic> raw;
}
