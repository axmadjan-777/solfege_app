import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

abstract final class SupabaseClientProvider {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) return;

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      // Implicit-флоу нужен, чтобы стандартное письмо подтверждения (его шаблон
      // на бесплатном тарифе со встроенным SMTP менять нельзя) работало на любом
      // устройстве: после серверной проверки Supabase возвращает токены прямо в
      // адресе (во фрагменте `#access_token=...`), и SDK сам поднимает сессию.
      // PKCE (`?code=...`) требует секрет из того же браузера и для писем,
      // открытых на другом устройстве, не подходит.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
  }
}
