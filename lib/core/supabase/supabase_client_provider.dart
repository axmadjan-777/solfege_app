import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

abstract final class SupabaseClientProvider {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) return;

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }
}
