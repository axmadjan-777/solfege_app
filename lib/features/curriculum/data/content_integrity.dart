import '../models/competency.dart';
import '../models/practice_set.dart';
import '../theory/music_formulas.dart';
import 'curriculum_catalog.dart';

enum IntegritySeverity { error, warning }

/// Одна проверка части 27, которую можно выполнить по JSON.
class IntegrityFinding {
  const IntegrityFinding(this.check, this.severity, this.detail);

  final String check;
  final IntegritySeverity severity;
  final String detail;

  bool get isError => severity == IntegritySeverity.error;
}

/// Проверки части 27 по загруженному каталогу. HTML и сверка с Markdown
/// здесь не выполняются: их нет в JSON.
class ContentIntegrity {
  const ContentIntegrity(this.catalog);

  final CurriculumCatalog catalog;

  List<IntegrityFinding> run() {
    final findings = <IntegrityFinding>[];
    _counts(findings);
    _uniqueIds(findings);
    _references(findings);
    _cycles(findings);
    _prerequisiteLevels(findings);
    _midi(findings);
    _formulas(findings);
    _sections(findings);
    _mvpClosure(findings);
    _microphone(findings);
    _levels(findings);
    _competencyHasCheck(findings);
    _tonalContext(findings);
    _antiAbsolutePitch(findings);
    _degreeDictation(findings);
    _triads(findings);
    _trainableLessons(findings);
    _introLessonWarning(findings);
    return findings;
  }

  void _counts(List<IntegrityFinding> findings) {
    _expect(findings, 'Схема lesson (уроки)', catalog.lessons.length, 114);
    _expect(findings, 'Схема competency', catalog.competencies.length, 162);
    _expect(findings, 'Схема exercise', catalog.practiceSets.length, 16);
    _expect(findings, 'Схема audio-item', catalog.audioItems.length, 15);
    _expect(findings, 'Шаблоны', catalog.templates.length, 13);
    _expect(findings, 'Уровни', catalog.levels.length, 12);
    final mvpLessons = catalog.lessons.where((l) => l.mvpStatus.isMvp).length;
    _expect(findings, 'Уроки MVP', mvpLessons, 56);
    final mvpTemplates = catalog.templates.where((t) => t.mvpStatus.isMvp).length;
    _expect(findings, 'Шаблоны MVP', mvpTemplates, 12);
  }

  void _uniqueIds(List<IntegrityFinding> findings) {
    _dupes(findings, 'Уникальность ID компетенций', [for (final c in catalog.competencies) c.id]);
    _dupes(findings, 'Уникальность ID уроков', [for (final l in catalog.lessons) l.id]);
    _dupes(findings, 'Уникальность ID тренажёров', [for (final p in catalog.practiceSets) p.id]);
    _dupes(findings, 'Уникальность ID шаблонов', [for (final t in catalog.templates) t.id]);
    _dupes(findings, 'Уникальность ID аудиоэлементов', [for (final a in catalog.audioItems) a.id]);
  }

  void _references(List<IntegrityFinding> findings) {
    final lessonIds = {for (final l in catalog.lessons) l.id};
    final competencyIds = {for (final c in catalog.competencies) c.id};
    final setIds = {for (final p in catalog.practiceSets) p.id};
    final templateIds = {for (final t in catalog.templates) t.id};
    final sourceIds = {for (final s in catalog.sources) s.id};
    final policyIds = {for (final p in catalog.config.reviewPolicies) p.id};
    final audioIds = {for (final a in catalog.audioItems) a.id};
    final missing = <String>[];

    for (final lesson in catalog.lessons) {
      if (!competencyIds.contains(lesson.primaryCompetency)) {
        missing.add('${lesson.id} primary ${lesson.primaryCompetency}');
      }
      for (final id in lesson.competencyIds) {
        if (!competencyIds.contains(id)) missing.add('${lesson.id} competency $id');
      }
      for (final ref in lesson.prerequisites) {
        if (ref.isLesson && !lessonIds.contains(ref.lessonId)) {
          missing.add('${lesson.id} prereq ${ref.raw}');
        }
        if (ref.competencyId != null && !competencyIds.contains(ref.competencyId)) {
          missing.add('${lesson.id} prereq ${ref.raw}');
        }
      }
      if (!templateIds.contains(lesson.interactionTemplate)) {
        missing.add('${lesson.id} template ${lesson.interactionTemplate}');
      }
      for (final id in lesson.practiceSetIds) {
        if (!setIds.contains(id)) missing.add('${lesson.id} practice $id');
      }
      if (!policyIds.contains(lesson.coldReviewPolicyId)) {
        missing.add('${lesson.id} policy ${lesson.coldReviewPolicyId}');
      }
      for (final id in lesson.sources) {
        if (!sourceIds.contains(id)) missing.add('${lesson.id} source $id');
      }
    }

    for (final competency in catalog.competencies) {
      for (final id in competency.prerequisites) {
        if (!competencyIds.contains(id)) missing.add('${competency.id} prereq $id');
      }
      final intro = competency.firstLessonId;
      if (intro != null && !lessonIds.contains(intro)) {
        missing.add('${competency.id} lesson $intro');
      }
      for (final id in competency.practiceSetIds) {
        if (!setIds.contains(id)) missing.add('${competency.id} practice $id');
      }
      if (!policyIds.contains(competency.reviewPolicyId)) {
        missing.add('${competency.id} policy ${competency.reviewPolicyId}');
      }
    }

    for (final set in catalog.practiceSets) {
      if (!templateIds.contains(set.interactionTemplate)) {
        missing.add('${set.id} template ${set.interactionTemplate}');
      }
      final alt = set.altInteractionTemplate;
      if (alt != null && !templateIds.contains(alt)) missing.add('${set.id} alt $alt');
      for (final id in set.competencyIds) {
        if (!competencyIds.contains(id)) missing.add('${set.id} competency $id');
      }
      for (final id in set.openedByLessonIds) {
        if (!lessonIds.contains(id)) missing.add('${set.id} opener $id');
      }
      for (final ref in set.prerequisites) {
        if (ref.competencyId != null && !competencyIds.contains(ref.competencyId)) {
          missing.add('${set.id} prereq ${ref.raw}');
        }
        if (ref.isLesson && !lessonIds.contains(ref.lessonId)) {
          missing.add('${set.id} prereq ${ref.raw}');
        }
      }
      for (final stage in set.stages) {
        for (final id in stage.competencyIds) {
          if (!competencyIds.contains(id)) missing.add('${set.id} stage competency $id');
        }
      }
    }

    for (final item in catalog.audioItems) {
      for (final id in item.usedBy) {
        if (!lessonIds.contains(id) && !setIds.contains(id)) {
          missing.add('${item.id} used_by $id');
        }
      }
      if (!audioIds.contains(item.id)) missing.add(item.id);
    }

    _okOr(findings, 'Ссылки уроков, компетенций и тренажёров', missing);
  }

  void _cycles(List<IntegrityFinding> findings) {
    final lessonEdges = {
      for (final lesson in catalog.lessons)
        lesson.id: [
          for (final ref in lesson.prerequisites)
            if (ref.lessonId != null) ref.lessonId!,
        ],
    };
    final competencyEdges = {
      for (final competency in catalog.competencies)
        competency.id: competency.prerequisites,
    };
    _okOr(
      findings,
      'Отсутствие циклов в графе уроков',
      _cycle(lessonEdges) ? ['цикл'] : [],
    );
    _okOr(
      findings,
      'Отсутствие циклов в графе компетенций',
      _cycle(competencyEdges) ? ['цикл'] : [],
    );
  }

  void _prerequisiteLevels(List<IntegrityFinding> findings) {
    final lessons = {for (final l in catalog.lessons) l.id: l};
    final competencies = {for (final c in catalog.competencies) c.id: c};
    final later = <String>[];
    for (final lesson in catalog.lessons) {
      for (final ref in lesson.prerequisites) {
        final earlier = ref.lessonId;
        if (earlier != null && lessons[earlier]!.level > lesson.level) {
          later.add('${lesson.id} ← $earlier');
        }
      }
    }
    for (final competency in catalog.competencies) {
      final intro = competency.firstLessonId;
      if (intro == null) continue;
      final level = lessons[intro]!.level;
      for (final id in competency.prerequisites) {
        final earlier = competencies[id]?.firstLessonId;
        if (earlier != null && lessons[earlier]!.level > level) {
          later.add('${competency.id} ← $id');
        }
      }
    }
    _okOr(findings, 'Предпосылки не ссылаются на более поздние уровни', later);
  }

  void _midi(List<IntegrityFinding> findings) {
    final bad = <String>[];
    void check(String label, Object? low, Object? high) {
      final lo = low is num ? low.toInt() : null;
      final hi = high is num ? high.toInt() : null;
      if (lo != null && (lo < 0 || lo > 127)) bad.add('$label low $lo');
      if (hi != null && (hi < 0 || hi > 127)) bad.add('$label high $hi');
      if (lo != null && hi != null && lo > hi) bad.add('$label $lo>$hi');
    }

    for (final item in catalog.audioItems) {
      check(item.id, item.midiLow, item.midiHigh);
    }
    for (final set in catalog.practiceSets) {
      for (final stage in set.stages) {
        check('${set.id}.${stage.stage}', stage.params['midi_low'], stage.params['midi_high']);
      }
    }
    for (final lesson in catalog.lessons) {
      check(lesson.id, lesson.audio['midi_low'], lesson.audio['midi_high']);
    }
    _okOr(findings, 'Корректность MIDI-диапазонов', bad);
  }

  void _formulas(List<IntegrityFinding> findings) {
    final bad = <String>[];
    for (final steps in MusicFormulas.scales.values) {
      if (MusicFormulas.sum(steps) != 12) bad.add('гамма $steps');
    }
    if (MusicFormulas.majorScale.toString() == MusicFormulas.naturalMinor.toString()) {
      bad.add('мажор совпал с натуральным минором');
    }
    const intervalLabels = {'м3': 3, 'б3': 4, 'ч4': 5, 'ч5': 7};
    for (final entry in intervalLabels.entries) {
      if (MusicFormulas.intervals[entry.key] != entry.value) bad.add(entry.key);
    }
    for (final set in catalog.practiceSets) {
      for (final stage in set.stages) {
        final types = stage.params['chord_types'];
        if (types is! List) continue;
        for (final type in types) {
          if (type is! String || !MusicFormulas.chords.containsKey(type)) {
            bad.add('${set.id}.${stage.stage} $type');
          }
        }
      }
    }
    const expected = {
      'major': [0, 4, 7],
      'minor': [0, 3, 7],
      'dim': [0, 3, 6],
      'aug': [0, 4, 8],
    };
    for (final entry in expected.entries) {
      if (MusicFormulas.chords[entry.key].toString() != entry.value.toString()) {
        bad.add(entry.key);
      }
    }
    _okOr(findings, 'Корректность формул интервалов, аккордов и гамм', bad);
  }

  void _sections(List<IntegrityFinding> findings) {
    const tracks = {
      'perception',
      'keyboard',
      'rhythm',
      'notation',
      'scale_degree',
      'interval',
      'chord',
      'harmony',
      'reading',
      'dictation',
      'voice',
      'analysis',
      'mixed',
    };
    const sections = {'theory', 'practice', 'both'};
    final bad = <String>[];
    for (final lesson in catalog.lessons) {
      if (!sections.contains(lesson.appSection) || !tracks.contains(lesson.skillTrack)) {
        bad.add(lesson.id);
      }
    }
    for (final set in catalog.practiceSets) {
      if (!sections.contains(set.appSection) || !tracks.contains(set.skillTrack)) {
        bad.add(set.id);
      }
    }
    _okOr(findings, 'У уроков и тренажёров заданы app_section и skill_track', bad);
  }

  void _mvpClosure(List<IntegrityFinding> findings) {
    final lessons = {for (final l in catalog.lessons) l.id: l};
    final competencies = {for (final c in catalog.competencies) c.id: c};
    final templates = {for (final t in catalog.templates) t.id: t};
    final bad = <String>[];

    for (final lesson in catalog.lessons.where((l) => l.mvpStatus.isMvp)) {
      for (final ref in lesson.prerequisites) {
        if (ref.lessonId != null && !lessons[ref.lessonId]!.mvpStatus.isMvp) {
          bad.add('${lesson.id} ← ${ref.raw}');
        }
        if (ref.competencyId != null && !competencies[ref.competencyId]!.mvpStatus.isMvp) {
          bad.add('${lesson.id} ← ${ref.raw}');
        }
      }
      final template = templates[lesson.interactionTemplate];
      if (template != null && !template.mvpStatus.isMvp) {
        bad.add('${lesson.id} template ${template.id}');
      }
    }

    for (final competency in catalog.competencies.where((c) => c.mvpStatus.isMvp)) {
      for (final id in competency.prerequisites) {
        final earlier = competencies[id]!;
        if (earlier.mvpStatus.isMvp) continue;
        final allowed = competency.id == 'ear.scale.major_minor' && id == 'sca.major_minor_third';
        if (!allowed) bad.add('${competency.id} ← $id');
      }
    }

    for (final set in catalog.practiceSets) {
      for (final stage in set.stages.where((s) => s.mvpStatus.isMvp)) {
        final template = templates[set.interactionTemplate];
        if (template != null && !template.mvpStatus.isMvp) {
          bad.add('${set.id}.${stage.stage} ${template.id}');
        }
      }
    }

    _okOr(findings, 'MVP замкнуто по предпосылкам', bad);
  }

  void _microphone(List<IntegrityFinding> findings) {
    final bad = [
      for (final set in catalog.practiceSets)
        if (set.mvpStatus.isMvp && set.requiresMicrophone) set.id,
    ];
    _okOr(findings, 'MVP реализуем без микрофона', bad);
  }

  void _levels(List<IntegrityFinding> findings) {
    final counts = <int, int>{};
    for (final lesson in catalog.lessons) {
      counts[lesson.level] = (counts[lesson.level] ?? 0) + 1;
    }
    final bad = <String>[];
    final byId = {for (final level in catalog.levels) level.id: level};
    for (final level in catalog.levels) {
      if (counts[level.number] != level.lessonCount) {
        bad.add('${level.id} declared ${level.lessonCount} actual ${counts[level.number]}');
      }
    }
    final seen = <String>{};
    final queue = [
      for (final level in catalog.levels)
        if (level.prerequisites.isEmpty) level.id,
    ];
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (!seen.add(id)) continue;
      for (final level in catalog.levels) {
        if (level.prerequisites.every(seen.contains)) queue.add(level.id);
      }
    }
    for (final level in catalog.levels) {
      if (!seen.contains(level.id) || level.prerequisites.any((id) => !byId.containsKey(id))) {
        bad.add('недостижим ${level.id}');
      }
    }
    _okOr(findings, 'Уровни: количество уроков и достижимость', bad);
  }

  void _competencyHasCheck(List<IntegrityFinding> findings) {
    final exams = {for (final level in catalog.levels) level.examId};
    final bad = <String>[];
    for (final competency in catalog.competencies) {
      final hasPath = competency.firstLessonId != null ||
          competency.practiceSetIds.isNotEmpty ||
          competency.levelExamId.isNotEmpty;
      if (!hasPath || !exams.contains(competency.levelExamId)) bad.add(competency.id);
    }
    _okOr(findings, 'У каждой компетенции есть способ проверки', bad);
  }

  void _tonalContext(List<IntegrityFinding> findings) {
    final bad = <String>[];
    for (final set in catalog.practiceSets) {
      for (final stage in set.stages) {
        final keys = stage.params['keys'];
        if (keys is! List || keys.isEmpty) continue;
        final context = stage.params['context'];
        if (context is! String || context.isEmpty || context == 'none') {
          bad.add('${set.id}.${stage.stage}');
        }
      }
    }
    _okOr(findings, 'Тональные слуховые стадии имеют контекст', bad);
  }

  void _antiAbsolutePitch(List<IntegrityFinding> findings) {
    final bad = <String>[];
    for (final set in catalog.practiceSets) {
      final tonal = set.stages.any((stage) {
        final keys = stage.params['keys'];
        return keys is List && keys.isNotEmpty;
      });
      if (tonal && (set.antiAbsolutePitch == null || set.antiAbsolutePitch!.isEmpty)) {
        bad.add(set.id);
      }
    }
    _okOr(findings, 'Слуховые тренажёры имеют защиту от абсолютной высоты', bad);
  }

  void _degreeDictation(List<IntegrityFinding> findings) {
    final set = catalog.practiceSet('PR-01');
    final degrees = <int>{};
    final shown = <int>[];
    for (final stage in set.stages) {
      degrees.addAll(stage.targetSet);
      if (stage.params['show_notation'] != false) shown.add(stage.stage);
    }
    final bad = <String>[];
    if (set.stages.length != 12) bad.add('стадий ${set.stages.length}');
    if (degrees.length != 7 || !degrees.containsAll(const {1, 2, 3, 4, 5, 6, 7})) {
      bad.add('ступени $degrees');
    }
    if (shown.isNotEmpty) bad.add('показ нот $shown');
    _okOr(findings, 'Ступеневый диктант: 12 стадий, 7 ступеней, ноты скрыты', bad);
  }

  void _triads(List<IntegrityFinding> findings) {
    const kinds = {'major', 'minor', 'dim', 'aug'};
    final heard = _chordTypes('PR-06');
    final built = _chordTypes('PR-07');
    final compared = _chordTypes('PR-06', stage: 3);
    final inverted = catalog.practiceSets
        .expand((set) => set.stages)
        .any((stage) => stage.params['inversions'] is List);
    final missing = <String>[];
    if (!heard.containsAll(kinds)) missing.add('слух ${kinds.difference(heard)}');
    if (!built.containsAll(kinds)) missing.add('построение ${kinds.difference(built)}');
    if (!compared.containsAll(kinds)) missing.add('сравнение ${kinds.difference(compared)}');
    if (!inverted) missing.add('обращения');
    _okOr(findings, 'Четыре вида трезвучий', missing);
  }

  void _trainableLessons(List<IntegrityFinding> findings) {
    final competencies = {for (final c in catalog.competencies) c.id: c};
    final bad = <String>[];
    for (final lesson in catalog.lessons) {
      final trained = competencies[lesson.primaryCompetency]?.practiceSetIds ?? const [];
      if (trained.isEmpty) continue;
      final linked = lesson.practiceSetIds.any(trained.contains);
      if (!linked) bad.add(lesson.id);
    }
    _okOr(findings, 'У тренируемых уроков есть привязанная практика', bad);
  }

  void _introLessonWarning(List<IntegrityFinding> findings) {
    final lessons = {for (final l in catalog.lessons) l.id: l};
    final warned = <String>[];
    for (final competency in catalog.competencies.where((c) => c.mvpStatus.isMvp)) {
      final intro = competency.firstLessonId;
      if (intro == null) continue;
      if (!lessons[intro]!.mvpStatus.isMvp) warned.add(competency.id);
    }
    if (warned.length == 1 && warned.single == 'ear.scale.major_minor') {
      findings.add(
        const IntegrityFinding(
          'MVP-компетенции с не-MVP уроком знакомства',
          IntegritySeverity.warning,
          'ear.scale.major_minor',
        ),
      );
      return;
    }
    findings.add(
      IntegrityFinding(
        'MVP-компетенции с не-MVP уроком знакомства',
        IntegritySeverity.error,
        warned.join(', '),
      ),
    );
  }

  Set<String> _chordTypes(String setId, {int? stage}) {
    final set = catalog.practiceSet(setId);
    final types = <String>{};
    for (final item in set.stages) {
      if (stage != null && item.stage != stage) continue;
      final raw = item.params['chord_types'];
      if (raw is! List) continue;
      for (final type in raw) {
        if (type is String) types.add(type);
      }
    }
    return types;
  }

  void _expect(List<IntegrityFinding> findings, String check, int actual, int expected) {
    if (actual == expected) return;
    findings.add(IntegrityFinding(check, IntegritySeverity.error, '$actual != $expected'));
  }

  void _dupes(List<IntegrityFinding> findings, String check, List<String> ids) {
    final seen = <String>{};
    final dupes = <String>[];
    for (final id in ids) {
      if (!seen.add(id)) dupes.add(id);
    }
    _okOr(findings, check, dupes);
  }

  void _okOr(List<IntegrityFinding> findings, String check, List<String> problems) {
    if (problems.isEmpty) return;
    findings.add(IntegrityFinding(check, IntegritySeverity.error, problems.join('; ')));
  }

  bool _cycle(Map<String, List<String>> edges) {
    const white = 0;
    const gray = 1;
    const black = 2;
    final color = {for (final id in edges.keys) id: white};
    bool visit(String id) {
      color[id] = gray;
      for (final next in edges[id] ?? const []) {
        final state = color[next] ?? white;
        if (state == gray) return true;
        if (state == white && visit(next)) return true;
      }
      color[id] = black;
      return false;
    }

    for (final id in edges.keys) {
      if (color[id] == white && visit(id)) return true;
    }
    return false;
  }
}

extension IntegrityReport on List<IntegrityFinding> {
  List<IntegrityFinding> get errors => where((f) => f.isError).toList();

  List<IntegrityFinding> get warnings =>
      where((f) => f.severity == IntegritySeverity.warning).toList();
}

/// Удобный доступ к компетенции без лишнего импорта в тестах ссылок.
extension CompetencyLookup on CurriculumCatalog {
  Competency? findCompetency(String id) {
    for (final competency in competencies) {
      if (competency.id == id) return competency;
    }
    return null;
  }

  PracticeSet? findPracticeSet(String id) {
    for (final set in practiceSets) {
      if (set.id == id) return set;
    }
    return null;
  }
}
