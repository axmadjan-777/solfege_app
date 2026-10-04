import '../models/competency.dart';
import '../models/curriculum_config.dart';
import '../models/json_reader.dart';
import '../models/lesson.dart';
import '../models/practice_set.dart';

/// Разобранная программа. Парсер не импортирует Flutter: тесты передают
/// уже декодированные карты, приложение читает ассеты отдельно.
class CurriculumCatalog {
  const CurriculumCatalog({
    required this.config,
    required this.levels,
    required this.sources,
    required this.audioItems,
    required this.templates,
    required this.practiceSets,
    required this.competencies,
    required this.lessons,
  });

  factory CurriculumCatalog.fromDecoded({
    required Map<String, dynamic> levels,
    required Map<String, dynamic> sourceMap,
    required Map<String, dynamic> audioManifest,
    required Map<String, dynamic> exercises,
    required Map<String, dynamic> competencies,
    required Map<String, dynamic> lessons,
  }) {
    final levelsReader = JsonReader.of(levels, 'levels');
    final config = CurriculumConfig.fromJson(levelsReader.object('config'));
    return CurriculumCatalog(
      config: config,
      levels: [
        for (final level in levelsReader.objects('levels')) Level.fromJson(level),
      ],
      sources: [
        for (final source in JsonReader.of(sourceMap, 'source-map').objects('sources'))
          SourceRef.fromJson(source),
      ],
      audioItems: [
        for (final item in JsonReader.of(audioManifest, 'audio-manifest').objects('items'))
          AudioItem.fromJson(item),
      ],
      templates: [
        for (final template in JsonReader.of(exercises, 'exercises').objects('interaction_templates'))
          InteractionTemplate.fromJson(template),
      ],
      practiceSets: [
        for (final set in JsonReader.of(exercises, 'exercises').objects('practice_sets'))
          PracticeSet.fromJson(set),
      ],
      competencies: [
        for (final competency in JsonReader.of(competencies, 'competencies').objects('competencies'))
          Competency.fromJson(competency),
      ],
      lessons: [
        for (final lesson in JsonReader.of(lessons, 'lessons').objects('lessons'))
          Lesson.fromJson(lesson),
      ],
    );
  }

  final CurriculumConfig config;
  final List<Level> levels;
  final List<SourceRef> sources;
  final List<AudioItem> audioItems;
  final List<InteractionTemplate> templates;
  final List<PracticeSet> practiceSets;
  final List<Competency> competencies;
  final List<Lesson> lessons;

  Lesson lesson(String id) => lessons.firstWhere((lesson) => lesson.id == id);

  Competency competency(String id) =>
      competencies.firstWhere((competency) => competency.id == id);

  PracticeSet practiceSet(String id) =>
      practiceSets.firstWhere((set) => set.id == id);

  AudioItem audioItem(String id) => audioItems.firstWhere((item) => item.id == id);

  Level level(String id) => levels.firstWhere((level) => level.id == id);
}
