import 'package:shared_preferences/shared_preferences.dart';

import '../../curriculum/data/curriculum_asset_source.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import 'clock.dart';
import 'progress_store.dart';

/// Каталог и книга прогресса на диске. Один экземпляр на запуск оболочки.
class PracticeProgressBinding {
  const PracticeProgressBinding({
    required this.catalog,
    required this.progress,
    required this.clock,
  });

  final CurriculumCatalog catalog;
  final ProgressStore progress;
  final Clock clock;
}

Future<PracticeProgressBinding> loadPracticeProgress() async {
  final catalog = await const CurriculumAssetSource().load();
  final preferences = await SharedPreferences.getInstance();
  const clock = SystemClock();
  return PracticeProgressBinding(
    catalog: catalog,
    clock: clock,
    progress: SharedPreferencesProgressStore(
      preferences: preferences,
      clock: clock,
      rules: catalog.config.masteryRules,
    ),
  );
}
