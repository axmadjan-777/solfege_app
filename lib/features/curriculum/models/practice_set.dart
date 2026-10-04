import 'json_reader.dart';
import 'mvp_status.dart';

/// Стадия тренажёра. Отличие стадий — в [params], не в отдельном UI.
class PracticeStage {
  const PracticeStage({
    required this.stage,
    required this.title,
    required this.competencyIds,
    required this.params,
    required this.feedback,
    required this.pass,
    required this.mvpStatus,
    required this.coldReview,
  });

  factory PracticeStage.fromJson(JsonReader r) {
    return PracticeStage(
      stage: r.integer('stage'),
      title: r.string('title'),
      competencyIds: r.optStrings('competency_ids'),
      params: r.object('params').json,
      feedback: r.optObject('feedback')?.json ?? const {},
      pass: r.object('pass').json,
      mvpStatus: MvpStatus.parse(r.string('mvp_status')),
      coldReview: r.optObject('cold_review')?.json,
    );
  }

  final int stage;
  final String title;
  final List<String> competencyIds;
  final Map<String, dynamic> params;
  final Map<String, dynamic> feedback;
  final Map<String, dynamic> pass;
  final MvpStatus mvpStatus;
  final Map<String, dynamic>? coldReview;

  bool get showsNotation => params['show_notation'] == true;

  List<int> get targetSet {
    final raw = params['target_set'];
    if (raw is! List) return const [];
    return [
      for (final value in raw)
        if (value is num) value.toInt(),
    ];
  }
}

/// Тренажёр практики (`exercises.json` → `practice_sets`).
class PracticeSet {
  const PracticeSet({
    required this.id,
    required this.title,
    required this.appSection,
    required this.skillTrack,
    required this.competencyIds,
    required this.interactionTemplate,
    required this.altInteractionTemplate,
    required this.openedByLessonIds,
    required this.prerequisites,
    required this.entryPoints,
    required this.antiAbsolutePitch,
    required this.reviewRule,
    required this.mvpStatus,
    required this.requiresMicrophone,
    required this.sources,
    required this.stages,
  });

  factory PracticeSet.fromJson(JsonReader r) {
    return PracticeSet(
      id: r.string('id'),
      title: r.string('title'),
      appSection: r.string('app_section'),
      skillTrack: r.string('skill_track'),
      competencyIds: r.strings('competency_ids'),
      interactionTemplate: r.string('interaction_template'),
      altInteractionTemplate: r.optString('alt_interaction_template'),
      openedByLessonIds: r.strings('opened_by_lesson_ids'),
      prerequisites: [
        for (final p in r.strings('prerequisite_ids')) PrerequisiteRef.parse(p),
      ],
      entryPoints: r.strings('entry_points'),
      antiAbsolutePitch: r.optString('anti_absolute_pitch'),
      reviewRule: r.string('review_rule'),
      mvpStatus: MvpStatus.parse(r.string('mvp_status')),
      requiresMicrophone: r.optBool('requires_microphone') ?? false,
      sources: r.optStrings('sources'),
      stages: [for (final s in r.objects('stages')) PracticeStage.fromJson(s)],
    );
  }

  final String id;
  final String title;
  final String appSection;
  final String skillTrack;
  final List<String> competencyIds;
  final String interactionTemplate;
  final String? altInteractionTemplate;
  final List<String> openedByLessonIds;
  final List<PrerequisiteRef> prerequisites;
  final List<String> entryPoints;
  final String? antiAbsolutePitch;
  final String reviewRule;
  final MvpStatus mvpStatus;
  final bool requiresMicrophone;
  final List<String> sources;
  final List<PracticeStage> stages;
}

/// UI-шаблон (`interaction_templates`).
class InteractionTemplate {
  const InteractionTemplate({
    required this.id,
    required this.title,
    required this.mvpStatus,
  });

  factory InteractionTemplate.fromJson(JsonReader r) {
    return InteractionTemplate(
      id: r.string('id'),
      title: r.string('title'),
      mvpStatus: MvpStatus.parse(r.string('mvp_status')),
    );
  }

  final String id;
  final String title;
  final MvpStatus mvpStatus;
}
