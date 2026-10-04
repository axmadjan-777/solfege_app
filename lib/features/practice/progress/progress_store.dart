import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../curriculum/models/curriculum_config.dart';
import 'attempt.dart';
import 'clock.dart';
import 'progress_rules.dart';

class CompetencySnapshot {
  const CompetencySnapshot({
    required this.status,
    required this.stability,
    required this.intervalStep,
    required this.dueAt,
    required this.provisionalAt,
  });

  final CompetencyStatus status;
  final Stability stability;
  final int intervalStep;
  final DateTime? dueAt;
  final DateTime? provisionalAt;

  Map<String, Object?> toJson() => {
        'status': status.id,
        'stability': [for (final session in stability.sessions) session.toJson()],
        'interval_step': intervalStep,
        'due_at': dueAt?.toIso8601String(),
        'provisional_at': provisionalAt?.toIso8601String(),
      };

  factory CompetencySnapshot.fromJson(Map<String, dynamic> json) => CompetencySnapshot(
        status: CompetencyStatus.parse(json['status'] as String),
        stability: Stability(
          sessions: [
            for (final session in json['stability'] as List)
              StabilitySession.fromJson(Map<String, dynamic>.from(session as Map)),
          ],
        ),
        intervalStep: json['interval_step'] as int,
        dueAt: json['due_at'] == null ? null : DateTime.parse(json['due_at'] as String),
        provisionalAt: json['provisional_at'] == null ? null : DateTime.parse(json['provisional_at'] as String),
      );
}

class ProgressBook {
  const ProgressBook({required this.userId, required this.competencies, required this.attempts});

  final String userId;
  final Map<String, CompetencySnapshot> competencies;
  final List<AttemptRecord> attempts;

  Map<String, Object?> toJson() => {
        'user_id': userId,
        'competencies': {for (final e in competencies.entries) e.key: e.value.toJson()},
        'attempts': [for (final attempt in attempts) attempt.toJson()],
      };

  factory ProgressBook.fromJson(Map<String, dynamic> json) => ProgressBook(
        userId: json['user_id'] as String? ?? 'local',
        competencies: {
          for (final entry in (json['competencies'] as Map).entries)
            entry.key as String: CompetencySnapshot.fromJson(Map<String, dynamic>.from(entry.value as Map)),
        },
        attempts: [
          for (final attempt in json['attempts'] as List)
            AttemptRecord.fromJson(Map<String, dynamic>.from(attempt as Map)),
        ],
      );

  static ProgressBook empty({String userId = 'local'}) =>
      ProgressBook(userId: userId, competencies: {}, attempts: []);
}

class SessionDraft {
  const SessionDraft({
    required this.competencyId,
    required this.sessionId,
    required this.correct,
    required this.policy,
    required this.tonality,
    this.critical = const [],
    this.coldReview = false,
    this.transfer = false,
    this.errorTag = '',
    this.itemSignature = 'item',
  });

  final String competencyId;
  final String sessionId;
  final List<bool> correct;
  final ReviewPolicy policy;
  final String tonality;
  final List<bool> critical;
  final bool coldReview;
  final bool transfer;
  final String errorTag;
  final String itemSignature;
}

abstract interface class ProgressStore {
  ProgressBook get book;

  CompetencySnapshot snapshot(String competencyId);

  void recordSession(SessionDraft session);

  List<String> openErrorTags();
}

class MemoryProgressStore implements ProgressStore {
  MemoryProgressStore({
    required this.clock,
    required this.rules,
    ProgressBook? book,
    this.userId = 'local',
  }) : book = book ?? ProgressBook.empty(userId: userId);

  final Clock clock;
  final MasteryRules rules;
  @override
  ProgressBook book;
  final String userId;

  @override
  CompetencySnapshot snapshot(String competencyId) {
    return book.competencies[competencyId] ??
        const CompetencySnapshot(
          status: CompetencyStatus.locked,
          stability: Stability(),
          intervalStep: 0,
          dueAt: null,
          provisionalAt: null,
        );
  }

  @override
  void recordSession(SessionDraft session) {
    final now = clock.now();
    final current = snapshot(session.competencyId);
    final fresh = <AttemptRecord>[
      for (var i = 0; i < session.correct.length; i++)
        AttemptRecord(
          competencyId: session.competencyId,
          sessionId: session.sessionId,
          itemSignature: '${session.itemSignature}-$i',
          errorTag: session.correct[i] ? '' : session.errorTag,
          competencyIds: [session.competencyId],
          isCorrect: session.correct[i],
          responseMs: 0,
          hintsUsed: 0,
          replays: 0,
          confidence: null,
          createdAt: now,
          tonality: session.tonality,
          critical: i < session.critical.length && session.critical[i],
          coldReview: session.coldReview,
          transfer: session.transfer,
        ),
    ];
    final attempts = [...book.attempts, ...fresh];
    final mine = attempts.where((a) => a.competencyId == session.competencyId).toList();
    final decision = MasteryDecision.evaluate(
      current: current.status,
      provisionalAt: current.provisionalAt,
      attempts: mine,
      now: now,
      coldReview: session.coldReview,
      immediateMinAccuracy: rules.immediateMinAccuracy,
      immediateWindow: rules.immediateWindow,
      immediateMaxCriticalErrors: rules.immediateMaxCriticalErrors,
      delayedMinAccuracy: rules.delayedMinAccuracy,
      delayedMinItems: rules.delayedMinItems,
      demotionAccuracyBelow: rules.demotionAccuracyBelow,
      demotionWindow: rules.demotionWindow,
    );
    final accuracy = fresh.where((a) => a.isCorrect).length / fresh.length;
    final stability = StabilityUpdate.addSession(
      current: current.stability,
      at: now,
      tonality: session.tonality,
      successful: accuracy >= rules.delayedMinAccuracy,
    );
    final step = ReviewStep.advance(
      intervalDays: session.policy.intervalDays,
      index: current.intervalStep,
      now: now,
      incorrect: accuracy < rules.delayedMinAccuracy,
      transfer: session.transfer && accuracy >= rules.delayedMinAccuracy,
    );
    final competencies = Map<String, CompetencySnapshot>.from(book.competencies);
    competencies[session.competencyId] = CompetencySnapshot(
      status: decision.status,
      stability: stability,
      intervalStep: step.index,
      dueAt: step.dueAt,
      provisionalAt: decision.markedProvisionalAt,
    );
    book = ProgressBook(userId: book.userId, competencies: competencies, attempts: attempts);
  }

  @override
  List<String> openErrorTags() {
    final latest = <String, bool>{};
    for (final attempt in book.attempts) {
      if (attempt.errorTag.isEmpty) continue;
      latest[attempt.errorTag] = attempt.isCorrect;
    }
    return [for (final entry in latest.entries) if (!entry.value) entry.key];
  }
}

class SharedPreferencesProgressStore implements ProgressStore {
  SharedPreferencesProgressStore({
    required SharedPreferences preferences,
    required this.clock,
    required this.rules,
    this.userId = 'local',
    this.storageKey = 'practice_progress_v1',
  }) : _preferences = preferences {
    final raw = _preferences.getString(storageKey);
    _memory = MemoryProgressStore(
      clock: clock,
      rules: rules,
      userId: userId,
      book: raw == null
          ? ProgressBook.empty(userId: userId)
          : ProgressBook.fromJson(jsonDecode(raw) as Map<String, dynamic>),
    );
  }

  final SharedPreferences _preferences;
  final Clock clock;
  final MasteryRules rules;
  final String userId;
  final String storageKey;
  late MemoryProgressStore _memory;

  @override
  ProgressBook get book => _memory.book;

  @override
  CompetencySnapshot snapshot(String competencyId) => _memory.snapshot(competencyId);

  @override
  void recordSession(SessionDraft session) {
    _memory.recordSession(session);
    _preferences.setString(storageKey, jsonEncode(book.toJson()));
  }

  @override
  List<String> openErrorTags() => _memory.openErrorTags();
}
