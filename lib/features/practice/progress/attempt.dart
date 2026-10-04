/// Статусы из `config.mastery_rules`. `stable` сюда не входит: он живёт в [Stability].
enum CompetencyStatus {
  locked('locked'),
  introduced('introduced'),
  practicing('practicing'),
  provisionallyPassed('provisionally_passed'),
  mastered('mastered'),
  needsReview('needs_review');

  const CompetencyStatus(this.id);

  final String id;

  static CompetencyStatus parse(String value) {
    return CompetencyStatus.values.firstWhere((status) => status.id == value);
  }
}

/// Три разнесённые верные сессии, одна из них в другой тональности.
class Stability {
  const Stability({this.sessions = const []});

  final List<StabilitySession> sessions;

  bool get reached => sessions.length >= 3 && sessions.map((s) => s.tonality).toSet().length >= 2;

  Stability add(StabilitySession session) => Stability(sessions: [...sessions, session]);
}

class StabilitySession {
  const StabilitySession({required this.at, required this.tonality});

  final DateTime at;
  final String tonality;

  Map<String, Object?> toJson() => {'at': at.toIso8601String(), 'tonality': tonality};

  factory StabilitySession.fromJson(Map<String, dynamic> json) => StabilitySession(
        at: DateTime.parse(json['at'] as String),
        tonality: json['tonality'] as String,
      );
}

/// Одна попытка. Поля части 15, которые уже нужны прогрессу.
class AttemptRecord {
  const AttemptRecord({
    required this.competencyId,
    required this.sessionId,
    required this.itemSignature,
    required this.errorTag,
    required this.competencyIds,
    required this.isCorrect,
    required this.responseMs,
    required this.hintsUsed,
    required this.replays,
    required this.confidence,
    required this.createdAt,
    required this.tonality,
    required this.critical,
    required this.coldReview,
    required this.transfer,
  });

  final String competencyId;
  final String sessionId;
  final String itemSignature;
  final String errorTag;
  final List<String> competencyIds;
  final bool isCorrect;
  final int responseMs;
  final int hintsUsed;
  final int replays;
  final double? confidence;
  final DateTime createdAt;
  final String tonality;
  final bool critical;
  final bool coldReview;
  final bool transfer;

  Map<String, Object?> toJson() => {
        'competency_id': competencyId,
        'session_id': sessionId,
        'item_signature': itemSignature,
        'error_tag': errorTag,
        'competency_ids': competencyIds,
        'is_correct': isCorrect,
        'response_ms': responseMs,
        'hints_used': hintsUsed,
        'replays': replays,
        'confidence': confidence,
        'created_at': createdAt.toIso8601String(),
        'tonality': tonality,
        'critical': critical,
        'cold_review': coldReview,
        'transfer': transfer,
      };

  factory AttemptRecord.fromJson(Map<String, dynamic> json) => AttemptRecord(
        competencyId: json['competency_id'] as String,
        sessionId: json['session_id'] as String,
        itemSignature: json['item_signature'] as String,
        errorTag: json['error_tag'] as String,
        competencyIds: [for (final id in json['competency_ids'] as List) id as String],
        isCorrect: json['is_correct'] as bool,
        responseMs: json['response_ms'] as int,
        hintsUsed: json['hints_used'] as int,
        replays: json['replays'] as int,
        confidence: (json['confidence'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        tonality: json['tonality'] as String,
        critical: json['critical'] as bool,
        coldReview: json['cold_review'] as bool,
        transfer: json['transfer'] as bool,
      );
}
