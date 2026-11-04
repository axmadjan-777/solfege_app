import 'dart:convert';
import 'dart:io';

import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/practice/trainers/degree_dictation.dart';
import 'package:solfege_app/features/practice/trainers/rhythm_dictation.dart';
import 'package:solfege_app/features/practice/trainers/stage_catalog.dart';
import 'package:test/test.dart';

void main() {
  late CurriculumCatalog catalog;

  setUpAll(() {
    catalog = CurriculumCatalog.fromDecoded(
      levels: _read('levels.json'),
      sourceMap: _read('source-map.json'),
      audioManifest: _read('audio-manifest.json'),
      exercises: _read('exercises.json'),
      competencies: _read('competencies.json'),
      lessons: _read('lessons.json'),
    );
  });

  test(
    'every mvp stage builds a passable session and the rest stays closed',
    () {
      const playable = {
        'PR-01',
        'PR-03',
        'PR-04',
        'PR-05',
        'PR-06',
        'PR-07',
        'PR-08',
        'PR-09',
        'PR-10',
        'PR-13',
      };
      for (final set in catalog.practiceSets) {
        for (final stage in set.stages) {
          if (!stage.mvpStatus.isMvp ||
              !playable.contains(set.id) ||
              stageUnavailableReason(set.id, stage.stage) != null) {
            if (playable.contains(set.id)) {
              expect(
                () => buildStageSession(set: set, stage: stage.stage, seed: 1),
                throwsStateError,
                reason: '${set.id} ${stage.stage}',
              );
            }
            continue;
          }
          final plan = buildStageSession(set: set, stage: stage.stage, seed: 1);
          expect(plan.tasks, isNotEmpty, reason: '${set.id} ${stage.stage}');
          expect(
            plan.tasks.every((task) => task.answerable),
            isTrue,
            reason: '${set.id} ${stage.stage}',
          );
          expect(
            plan.tasks.every(
              (task) => task.showNotation == stage.showsNotation,
            ),
            isTrue,
            reason: '${set.id} ${stage.stage}',
          );
          expect(
              plan.passed(plan.tasks.length,
                  responseMs: List.filled(plan.tasks.length, 1000)),
              isTrue);
          expect(plan.passed(0), isFalse);
          final low = stage.params['midi_low'];
          final high = stage.params['midi_high'];
          if (low is num && high is num) {
            for (final task in plan.tasks) {
              for (final midi in task.soundedMidi) {
                expect(
                  midi,
                  inInclusiveRange(low.toInt(), high.toInt()),
                  reason: '${set.id} ${stage.stage}',
                );
              }
            }
          }
        }
      }
    },
  );

  test('PR-08 speed stage requires a measured median within the declared limit',
      () {
    final plan =
        buildStageSession(set: catalog.practiceSet('PR-08'), stage: 3, seed: 1);
    expect(plan.passMetric, 'median_response_ms');
    expect(plan.responseThresholdMs, 2000);
    expect(plan.passed(plan.tasks.length), isFalse);
    expect(
        plan.passed(plan.tasks.length,
            responseMs: List.filled(plan.tasks.length, 2000)),
        isTrue);
    expect(
        plan.passed(plan.tasks.length,
            responseMs: List.filled(plan.tasks.length, 2001)),
        isFalse);
    expect(plan.passed(0, responseMs: List.filled(plan.tasks.length, 1000)),
        isFalse);
    expect(medianResponseMs([3000, 1000, 1000, 3000]), 2000);
    expect(medianResponseMs([3000, 1000, 2000]), 2000);
  });

  test('PR-01 hides notes, credits the octave and changes register', () {
    final set = catalog.practiceSet('PR-01');
    final stage1 = buildStageSession(set: set, stage: 1, seed: 1);
    expect(stage1.tasks, hasLength(10));
    expect(stage1.tasks.every((task) => task.showNotation), isFalse);
    expect(stage1.passed(8), isTrue);
    expect(stage1.passed(7), isFalse);
    expect(
      stage1.tasks.first.audio!.events.whereType<RestEvent>().single.durationMs,
      500,
    );

    final stage8 = buildStageSession(set: set, stage: 8, seed: 1);
    expect(stage8.tasks[0].answer, '1');
    expect(stage8.tasks[2].answer, '1');
    expect(stage8.tasks[0].soundedMidi.single, inInclusiveRange(60, 71));
    expect(
      stage8.tasks[1].soundedMidi.single,
      stage8.tasks[0].soundedMidi.single,
    );
    expect(stage8.tasks[2].soundedMidi.single, 72);
    expect(
      DegreeDictation.accepts(tonicMidi: 60, noteMidi: 72, answer: 1),
      isTrue,
    );

    final stage12 = buildStageSession(set: set, stage: 12, seed: 1);
    expect(stage12.tasks[0].tonality, 'G');
    expect(stage12.tasks[1].tonality, 'G');
    expect(stage12.tasks[2].tonality, 'F');
    expect(stage12.tasks[2].prompt, contains('фа'));
  });

  test('a fourth is four degrees and the next stage waits', () {
    final intervals = catalog.practiceSet('PR-03');
    final offers = stageOffers(intervals, const {});
    expect(offers[0].access, StageAccess.open);
    expect(offers[1].access, StageAccess.locked);
    expect(offers[3].access, StageAccess.soon);
    final heard = buildStageSession(set: intervals, stage: 2, seed: 3);
    final signatures =
        heard.tasks.map((task) => task.soundedMidi.join(':')).toSet();
    expect(signatures, hasLength(heard.tasks.length));
    expect(heard.tasks.every((task) => task.choices.contains('ч5')), isFalse);

    final counting = catalog.practiceSet('PR-04');
    final numbers = buildStageSession(set: counting, stage: 1, seed: 1);
    final fourth = numbers.tasks.firstWhere(
      (task) => task.visible == 'до — фа',
    );
    expect(fourth.answer, '4');
    expect(fourth.choices, contains('3'));
  });

  test('PR-07 stage 4 opens after stage 2 while stage 3 stays ahead', () {
    final set = catalog.practiceSet('PR-07');
    final closed = stageOffers(set, const {1});
    expect(
      closed.firstWhere((offer) => offer.stage == 3).access,
      StageAccess.soon,
    );
    expect(
      closed.firstWhere((offer) => offer.stage == 4).access,
      StageAccess.locked,
    );
    final open = stageOffers(set, const {1, 2});
    expect(
      open.firstWhere((offer) => offer.stage == 3).access,
      StageAccess.soon,
    );
    expect(
      open.firstWhere((offer) => offer.stage == 4).access,
      StageAccess.open,
    );
    final fix = buildStageSession(set: set, stage: 4, seed: 1);
    expect(fix.tasks.first.showNotation, isTrue);
    expect(fix.tasks.first.choices, ['терцию', 'квинту']);
  });

  test('rhythm bars add up and a miss names the bar', () {
    final set = catalog.practiceSet('PR-10');
    final plan = buildStageSession(set: set, stage: 2, seed: 2);
    for (final task in plan.tasks) {
      for (final bar in task.answer.split(' / ')) {
        expect(
          RhythmDictation.barFits(splitRhythmBar(bar), beatsInBar: task.beats),
          isTrue,
          reason: bar,
        );
      }
      final played = task.audio!.events.skip(task.beats * 2 + 1).toList();
      final totalMs = played.fold<int>(
          0,
          (total, event) =>
              total +
              switch (event) {
                NoteEvent(:final durationMs) => durationMs,
                RestEvent(:final durationMs) => durationMs,
                ChordEvent(:final durationMs) => durationMs,
              });
      expect(totalMs, task.beats * 2 * 750);
      expect(played.whereType<NoteEvent>(), isNotEmpty);
    }
    expect(wrongBarOf('четверть / половинная', 'четверть / четверть'), 2);
    expect(wrongBarOf('четверть / четверть', 'четверть / четверть'), isNull);

    final pulse = buildStageSession(
      set: catalog.practiceSet('PR-09'),
      stage: 1,
      seed: 1,
    );
    final task = pulse.tasks.first;
    expect(task.gapMs, lessThanOrEqualTo(1000));
    final hits = [for (var i = 1; i <= task.beats; i++) task.gapMs * i];
    expect(
      tapsMatchGrid(
        hits,
        beats: task.beats,
        gapMs: task.gapMs,
        toleranceMs: task.toleranceMs,
      ),
      isTrue,
    );
    expect(task.toleranceMs, 120);
  });

  test('unscored rhythm stages stay unavailable and do not block later stages',
      () {
    for (final id in ['PR-13', 'PR-09', 'PR-01']) {
      final set = catalog.practiceSet(id);
      final offers =
          stageOffers(set, {for (final stage in set.stages) stage.stage});
      for (final offer in offers) {
        if (stageUnavailableReason(id, offer.stage) != null) {
          expect(offer.access, StageAccess.soon);
          expect(offer.unavailableReason, contains('ритма'));
          expect(() => buildStageSession(set: set, stage: offer.stage, seed: 4),
              throwsStateError);
        }
      }
    }
    final degrees = stageOffers(
        catalog.practiceSet('PR-01'), {for (var i = 1; i <= 10; i++) i});
    expect(degrees.firstWhere((offer) => offer.stage == 12).access,
        StageAccess.open);
  });

  test('a passed stage survives the next answer and a reload', () {
    final clock = FixedClock(DateTime.utc(2026, 10, 5, 9));
    final store = MemoryProgressStore(
      clock: clock,
      rules: catalog.config.masteryRules,
    );
    store.markStagePassed('PR-01', 1);
    store.recordSession(
      SessionDraft(
        competencyId: 'sca.tonic',
        sessionId: 'keep',
        correct: const [true],
        policy: catalog.config.policy('RP-aural'),
        tonality: 'C',
      ),
    );
    store.scheduleNextDayReturn('PR-01');
    expect(store.book.passedStages['PR-01'], [1]);
    final restored = ProgressBook.fromJson(
      jsonDecode(jsonEncode(store.book.toJson())) as Map<String, dynamic>,
    );
    expect(restored.passedStages['PR-01'], [1]);
    expect(restored.returns, isNotEmpty);
  });
}

Map<String, dynamic> _read(String name) {
  return Map<String, dynamic>.from(
    jsonDecode(File('assets/curriculum/$name').readAsStringSync()) as Map,
  );
}
