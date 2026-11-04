import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../curriculum/data/curriculum_asset_source.dart';
import '../../curriculum/data/curriculum_catalog.dart';
import 'account_progress_store.dart';
import 'clock.dart';
import 'practice_book_sync.dart';

class PracticeProgressBinding {
  const PracticeProgressBinding(
      {required this.catalog, required this.progress, required this.clock});
  final CurriculumCatalog catalog;
  final AccountProgressStore progress;
  final Clock clock;
}

/// Identity is captured before the first await. A replaced auth scope cannot
/// adopt an old asynchronous result, even after A → B → A.
Future<PracticeProgressBinding> loadPracticeProgress({
  required String userId,
  required bool Function() isCurrent,
}) async {
  void check() {
    if (!isCurrent()) throw PracticeAccountChanged();
  }

  check();
  final catalog = await const CurriculumAssetSource().load();
  check();
  final preferences = await SharedPreferences.getInstance();
  await AccountProgressStore.pendingLocalWrites(userId);
  check();
  const clock = SystemClock();
  final store = AccountProgressStore(
    preferences: preferences,
    userId: userId,
    clock: clock,
    rules: catalog.config.masteryRules,
    currentUserId: () => isCurrent() ? userId : null,
    remote: SupabaseConfig.isConfigured
        ? PracticeBookSync(Supabase.instance.client)
        : null,
  );
  store.startSync();
  return PracticeProgressBinding(
      catalog: catalog, clock: clock, progress: store);
}
