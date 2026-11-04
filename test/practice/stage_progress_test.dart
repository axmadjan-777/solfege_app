import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/progress/attempt.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/practice/progress/practice_attempt.dart';
import 'package:solfege_app/features/practice/progress/stage_progress.dart';
import 'package:solfege_app/features/practice/trainers/stage_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CurriculumCatalog catalog;
  late FixedClock clock;
  late MemoryProgressStore store;

  setUpAll(() {
    catalog = _catalog();
  });
  setUp(() {
    clock = FixedClock(DateTime.utc(2026, 11, 5, 9));
    store =
        MemoryProgressStore(clock: clock, rules: catalog.config.masteryRules);
    SharedPreferences.setMockInitialValues({});
  });

  void answer(String id, int stage, StageTask task,
      {bool correct = true, String? reviewId, String? session}) {
    recordStageAnswer(
      store: store,
      catalog: catalog,
      set: catalog.practiceSet(id),
      stage: stage,
      task: task,
      correct: correct,
      sessionId: session ?? 'training-${store.book.attempts.length}',
      reviewCompetencyId: reviewId,
      now: clock.now(),
    );
  }

  StageTask taskFor(String id, int stage, String competencyId) {
    for (var seed = 1; seed <= 20; seed++) {
      final plan = buildStageSession(
          set: catalog.practiceSet(id), stage: stage, seed: seed);
      for (final task in plan.tasks) {
        if (task.competencyIds.contains(competencyId)) return task;
      }
    }
    throw StateError('No task for $competencyId');
  }

  void learn(String id, int stage, String competencyId) {
    final spec = catalog
        .practiceSet(id)
        .stages
        .firstWhere((item) => item.stage == stage);
    final profile = stageCompetencyPolicy(
        catalog: catalog, stage: spec, competencyId: competencyId);
    final task = taskFor(id, stage, competencyId);
    for (var i = 0; i < profile.rules.immediateWindow; i++) {
      answer(id, stage, task);
    }
    expect(store.snapshot(competencyId).status,
        CompetencyStatus.provisionallyPassed);
  }

  test('PR-01 stages 4/12 and PR-03 stage 3 record their own objectives', () {
    final examples = [
      ('PR-01', 4, 'ear.degree.major.2'),
      ('PR-01', 12, 'ear.degree.transfer_keys'),
      ('PR-03', 3, 'ear.interval.p4_p5'),
    ];
    for (final (id, stage, competency) in examples) {
      final start = store.book.attempts.length;
      for (final task in buildStageSession(
              set: catalog.practiceSet(id), stage: stage, seed: 3)
          .tasks) {
        answer(id, stage, task);
      }
      final fresh = store.book.attempts.skip(start);
      expect(fresh, isNotEmpty);
      expect(
          fresh.every((attempt) => attempt.competencyIds.contains(competency)),
          isTrue);
      expect(store.snapshot(competency).status, isNot(CompetencyStatus.locked));
    }
    expect(store.book.competencies, isNot(contains('sca.tonic')));
    expect(store.book.competencies, isNot(contains('ear.interval.m3_M3')));
  });

  test(
      'independent objectives get only their relevant answers; joint evidence is one attempt',
      () {
    answer('PR-01', 2, taskFor('PR-01', 2, 'ear.degree.major.1'));
    expect(store.snapshot('ear.degree.major.1').status,
        CompetencyStatus.practicing);
    expect(
        store.snapshot('ear.degree.major.5').status, CompetencyStatus.locked);
    answer('PR-01', 2, taskFor('PR-01', 2, 'ear.degree.major.5'));
    expect(store.book.attempts.last.competencyIds, ['ear.degree.major.5']);
    final before = store.book.attempts.length;
    final pulse =
        buildStageSession(set: catalog.practiceSet('PR-09'), stage: 1, seed: 3)
            .tasks
            .first;
    answer('PR-09', 1, pulse);
    expect(store.book.attempts, hasLength(before + 1));
    expect(store.book.attempts.last.competencyIds.toSet(),
        {'rhy.pulse_tap', 'rhy.beat_tempo'});
    expect(store.snapshot('rhy.pulse_tap').status, CompetencyStatus.practicing);
    expect(
        store.snapshot('rhy.beat_tempo').status, CompetencyStatus.practicing);
  });

  test(
      'cold review uses each skill clock/count and does not master its sibling',
      () {
    const a = 'ear.degree.major.1';
    const b = 'ear.degree.major.5';
    final set = catalog.practiceSet('PR-01');
    final spec = set.stages.firstWhere((item) => item.stage == 2);
    learn('PR-01', 2, a);
    clock.advance(const Duration(hours: 10));
    learn('PR-01', 2, b);
    final profile =
        stageCompetencyPolicy(catalog: catalog, stage: spec, competencyId: a);
    final wait = Duration(hours: profile.policy.firstDelayRangeHours.$1);
    clock.advance(wait - const Duration(hours: 10));
    expect(
        stageReviewBlockReason(
            catalog: catalog,
            set: set,
            stage: 2,
            competencyId: a,
            store: store,
            now: clock.now()),
        isNull);
    expect(
        stageReviewBlockReason(
            catalog: catalog,
            set: set,
            stage: 2,
            competencyId: b,
            store: store,
            now: clock.now()),
        isNotNull);
    final plan = buildStageReviewSession(
        catalog: catalog, set: set, stage: 2, competencyId: a, seed: 7);
    expect(plan.tasks, hasLength(catalog.competency(a).coldReviewMinItems));
    expect(plan.tasks.map((task) => task.answer).toSet(), {'1', '5'});
    for (var i = 0; i < plan.tasks.length; i++) {
      answer('PR-01', 2, plan.tasks[i], reviewId: a, session: 'cold-a');
      if (i + 1 < plan.tasks.length) {
        expect(store.snapshot(a).status, isNot(CompetencyStatus.mastered));
      }
    }
    expect(store.snapshot(a).status, CompetencyStatus.mastered);
    expect(store.snapshot(b).status, CompetencyStatus.provisionallyPassed);
    expect(store.book.passedStages, isEmpty);
    clock.advance(const Duration(hours: 10));
    final other = buildStageReviewSession(
        catalog: catalog, set: set, stage: 2, competencyId: b, seed: 11);
    for (final task in other.tasks) {
      answer('PR-01', 2, task, reviewId: b, session: 'cold-b');
    }
    expect(store.snapshot(b).status, CompetencyStatus.mastered);
  });

  test(
      'early review cannot write evidence and a failed complete review starts a new wait',
      () {
    const id = 'ear.degree.major.2';
    final set = catalog.practiceSet('PR-01');
    final spec = set.stages.firstWhere((item) => item.stage == 4);
    learn('PR-01', 4, id);
    final profile =
        stageCompetencyPolicy(catalog: catalog, stage: spec, competencyId: id);
    final plan = buildStageReviewSession(
        catalog: catalog, set: set, stage: 4, competencyId: id, seed: 2);
    final before = store.book.attempts.length;
    expect(
        () => answer('PR-01', 4, plan.tasks.first,
            reviewId: id, session: 'early'),
        throwsStateError);
    expect(store.book.attempts, hasLength(before));
    clock.advance(Duration(hours: profile.policy.firstDelayRangeHours.$1));
    for (final task in plan.tasks) {
      answer('PR-01', 4, task, correct: false, reviewId: id, session: 'failed');
    }
    expect(store.snapshot(id).status, CompetencyStatus.needsReview);
    expect(store.snapshot(id).provisionalAt, isNull);
    learn('PR-01', 4, id);
    expect(store.snapshot(id).provisionalAt, clock.now());
    expect(
        stageReviewBlockReason(
            catalog: catalog,
            set: set,
            stage: 4,
            competencyId: id,
            store: store,
            now: clock.now()),
        contains('через'));
  });

  test('legacy review cannot bypass the competency minimum with four answers',
      () {
    const id = 'ear.interval.m3_M3';
    for (var i = 0; i < catalog.config.masteryRules.immediateWindow; i++) {
      recordPracticeAnswer(
          store: store, catalog: catalog, setId: 'PR-03', correct: true);
    }
    final profile = practiceReviewPolicy(catalog, 'PR-03');
    expect(profile.rules.delayedMinItems,
        catalog.competency(id).coldReviewMinItems);
    expect(profile.rules.delayedMinItems,
        greaterThan(catalog.config.masteryRules.delayedMinItems));
    clock.advance(Duration(hours: profile.policy.firstDelayRangeHours.$1));
    for (var i = 0; i < profile.rules.delayedMinItems; i++) {
      recordPracticeAnswer(
          store: store,
          catalog: catalog,
          setId: 'PR-03',
          correct: true,
          coldReview: true,
          sessionId: 'legacy');
      if (i + 1 < profile.rules.delayedMinItems) {
        expect(store.snapshot(id).status, isNot(CompetencyStatus.mastered));
      }
    }
    expect(store.snapshot(id).status, CompetencyStatus.mastered);
  });

  test('stage 12 uses stricter stage cold min_items instead of generic four',
      () {
    final set = catalog.practiceSet('PR-01');
    final stage = set.stages.firstWhere((item) => item.stage == 12);
    final profile = stageCompetencyPolicy(
        catalog: catalog,
        stage: stage,
        competencyId: 'ear.degree.transfer_keys');
    expect(profile.rules.delayedMinItems, 7);
    expect(
        buildStageReviewSession(
                catalog: catalog,
                set: set,
                stage: 12,
                competencyId: 'ear.degree.transfer_keys',
                seed: 1)
            .tasks,
        hasLength(7));
  });

  test(
      'all enabled stages expose each declared objective without crediting unrelated ones',
      () {
    for (final set in catalog.practiceSets
        .where((set) => stageSessionSetIds.contains(set.id))) {
      for (final stage in set.stages.where((stage) =>
          stage.mvpStatus.isMvp &&
          stageUnavailableReason(set.id, stage.stage) == null)) {
        final assessed = <String>{};
        for (var seed = 1; seed <= 10; seed++) {
          for (final task
              in buildStageSession(set: set, stage: stage.stage, seed: seed)
                  .tasks) {
            expect(
                task.competencyIds.every(stage.competencyIds.contains), isTrue,
                reason: '${set.id}/${stage.stage}');
            assessed.addAll(task.competencyIds);
          }
        }
        expect(assessed, stage.competencyIds.toSet(),
            reason: '${set.id}/${stage.stage}');
      }
    }
  });

  test(
      'multi-ID attempts, individual mastery and passed stages survive persistence',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final persistent = SharedPreferencesProgressStore(
        preferences: prefs, clock: clock, rules: catalog.config.masteryRules);
    final pulse =
        buildStageSession(set: catalog.practiceSet('PR-09'), stage: 1, seed: 1)
            .tasks
            .first;
    for (var i = 0; i < catalog.config.masteryRules.immediateWindow; i++) {
      recordStageAnswer(
          store: persistent,
          catalog: catalog,
          set: catalog.practiceSet('PR-09'),
          stage: 1,
          task: pulse,
          correct: true,
          sessionId: 'pulse-$i',
          now: clock.now());
    }
    persistent.markStagePassed('PR-09', 1);
    final spec = catalog.practiceSet('PR-09').stages.first;
    final profile = stageCompetencyPolicy(
        catalog: catalog, stage: spec, competencyId: 'rhy.pulse_tap');
    clock.advance(Duration(hours: profile.policy.firstDelayRangeHours.$1));
    final review = buildStageReviewSession(
        catalog: catalog,
        set: catalog.practiceSet('PR-09'),
        stage: 1,
        competencyId: 'rhy.pulse_tap',
        seed: 4);
    for (final task in review.tasks) {
      recordStageAnswer(
          store: persistent,
          catalog: catalog,
          set: catalog.practiceSet('PR-09'),
          stage: 1,
          task: task,
          correct: true,
          sessionId: 'pulse-cold',
          reviewCompetencyId: 'rhy.pulse_tap',
          now: clock.now());
    }
    final restored = SharedPreferencesProgressStore(
        preferences: prefs, clock: clock, rules: catalog.config.masteryRules);
    expect(restored.book.attempts.first.competencyIds, pulse.competencyIds);
    expect(restored.book.attempts.last.competencyIds, ['rhy.pulse_tap']);
    expect(
        restored.snapshot('rhy.pulse_tap').status, CompetencyStatus.mastered);
    expect(restored.snapshot('rhy.beat_tempo').status,
        CompetencyStatus.provisionallyPassed);
    expect(restored.book.passedStages['PR-09'], [1]);
    final roundTrip = ProgressBook.fromJson(
        jsonDecode(jsonEncode(restored.book.toJson())) as Map<String, dynamic>);
    expect(roundTrip.attempts.first.competencyIds, pulse.competencyIds);
  });
}

CurriculumCatalog _catalog() {
  Map<String, dynamic> read(String name) => Map<String, dynamic>.from(
      jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map);
  return CurriculumCatalog.fromDecoded(
      levels: read('levels.json'),
      sourceMap: read('source-map.json'),
      audioManifest: read('audio-manifest.json'),
      exercises: read('exercises.json'),
      competencies: read('competencies.json'),
      lessons: read('lessons.json'));
}
