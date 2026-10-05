import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../curriculum/data/curriculum_asset_source.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import 'clock.dart';
import 'practice_book_rows.dart';
import 'practice_book_sync.dart';
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
  final store = SharedPreferencesProgressStore(
    preferences: preferences,
    clock: clock,
    rules: catalog.config.masteryRules,
  );
  await _attachRemoteBook(store);
  return PracticeProgressBinding(
    catalog: catalog,
    clock: clock,
    progress: store,
  );
}

Future<void> _attachRemoteBook(SharedPreferencesProgressStore store) async {
  if (!SupabaseConfig.isConfigured) return;
  final SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    return;
  }
  final sync = PracticeBookSync(client);
  try {
    final remote = await sync.pull();
    if (adoptRemoteBook(
      localAttempts: store.book.attempts.length,
      remoteExists: remote != null,
    )) {
      store.adoptBook(remote!);
    }
    store.onBookChanged = (book) {
      sync.push(book);
    };
    if (store.book.attempts.isNotEmpty) await sync.push(store.book);
  } catch (_) {
    return;
  }
}
