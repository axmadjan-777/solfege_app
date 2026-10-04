import 'dart:convert';

import 'package:flutter/services.dart';

import 'curriculum_catalog.dart';

/// Загрузка шести JSON из ассетов. Тесты читают файлы с диска и этот класс не зовут.
class CurriculumAssetSource {
  const CurriculumAssetSource();

  static const directory = 'assets/curriculum';

  Future<CurriculumCatalog> load() async {
    final levels = await _read('levels.json');
    final sourceMap = await _read('source-map.json');
    final audio = await _read('audio-manifest.json');
    final exercises = await _read('exercises.json');
    final competencies = await _read('competencies.json');
    final lessons = await _read('lessons.json');
    return CurriculumCatalog.fromDecoded(
      levels: levels,
      sourceMap: sourceMap,
      audioManifest: audio,
      exercises: exercises,
      competencies: competencies,
      lessons: lessons,
    );
  }

  Future<Map<String, dynamic>> _read(String name) async {
    final text = await rootBundle.loadString('$directory/$name');
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw FormatException('$name: ожидался объект');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
