import 'dart:convert';

/// Supabase connection settings via --dart-define.
///
/// Example:
/// flutter run -d chrome \
///   --dart-define=SUPABASE_URL=https://zehmcszijutthmeswtci.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static const defaultProjectUrl = 'https://zehmcszijutthmeswtci.supabase.co';

  /// URL, на который Supabase редиректит из писем подтверждения email.
  ///
  /// По умолчанию — продакшен на GitHub Pages. Можно переопределить через
  /// `--dart-define=AUTH_REDIRECT_URL=...` (например, для локальной разработки).
  /// Этот же адрес должен быть в Supabase Dashboard → Authentication → URL
  /// Configuration → Redirect URLs, иначе Supabase подставит свой Site URL.
  static const _redirectUrlOverride =
      String.fromEnvironment('AUTH_REDIRECT_URL');

  static const defaultRedirectUrl =
      'https://axmadjan-777.github.io/solfege_app/';

  static String get emailRedirectUrl => _redirectUrlOverride.isNotEmpty
      ? _redirectUrlOverride
      : defaultRedirectUrl;

  static bool get isConfigured =>
      url.isNotEmpty && classifySupabaseKey(publishableKey).isClientSafe;

  static String get diagnosticMessage =>
      diagnosticFor(key: publishableKey, url: url);

  /// Текст для экрана настройки. [key] — значение `SUPABASE_PUBLISHABLE_KEY`.
  static String diagnosticFor({required String key, required String url}) {
    final kind = classifySupabaseKey(key);
    return switch (kind) {
      SupabaseKeyKind.placeholder =>
        'В dart_defines.json остался шаблон YOUR_PUBLISHABLE_KEY. '
            'Вставьте publishable key из Supabase Dashboard → API.',
      SupabaseKeyKind.secret || SupabaseKeyKind.serviceRole =>
        'В клиент передан секретный ключ. Браузер с ним всегда отвечает 401: '
            'шлюз не принимает sb_secret_ и service_role. '
            'Нужен publishable key (sb_publishable_…), секретный в приложение не кладётся.',
      SupabaseKeyKind.accessToken =>
        'В SUPABASE_PUBLISHABLE_KEY попал токен управления sbp_. '
            'Им ходят на api.supabase.com, не в браузер. Такой запрос отвечает 401. '
            'Нужен publishable key.',
      SupabaseKeyKind.missing || SupabaseKeyKind.unknown => _missing(key, url),
      SupabaseKeyKind.publishable || SupabaseKeyKind.legacyAnon =>
        url.isEmpty
            ? _missing(key, url)
            : 'Ключ подходит для клиента и уходит в заголовок apikey.',
    };
  }

  static String _missing(String key, String url) {
    final missing = <String>[
      if (url.isEmpty) 'SUPABASE_URL',
      if (key.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
    ];
    if (key.isNotEmpty && !classifySupabaseKey(key).isClientSafe) {
      return 'Ключ не похож на publishable. Ожидается sb_publishable_… или anon JWT.';
    }
    if (missing.isEmpty) return 'Переменные переданы, но конфигурация неполная.';
    return 'Не получены: ${missing.join(', ')}. '
        'Скорее всего --dart-define не попали в сборку '
        '(нужен полный перезапуск flutter run, без пустых строк в команде).';
  }

  static String get configurationHint =>
      'Рекомендуемый способ — файл dart_defines.json:\n'
      '1. cp dart_defines.example.json dart_defines.json\n'
      '2. Вставьте publishable key в dart_defines.json\n'
      '3. flutter run -d chrome --dart-define-from-file=dart_defines.json\n\n'
      'Или одной строкой (без пустых строк между \\\\):\n'
      'Передайте SUPABASE_URL и SUPABASE_PUBLISHABLE_KEY через --dart-define.\n'
      'Пример:\n'
      'flutter run -d chrome \\\n'
      '  --dart-define=SUPABASE_URL=$defaultProjectUrl \\\n'
      '  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY';
}

/// Какой ключ попал в клиент. Секретный и токен управления в браузер не отправляются:
/// шлюз отвечает им 401.
enum SupabaseKeyKind {
  missing,
  placeholder,
  publishable,
  legacyAnon,
  secret,
  serviceRole,
  accessToken,
  unknown;

  bool get isClientSafe =>
      this == SupabaseKeyKind.publishable || this == SupabaseKeyKind.legacyAnon;
}

SupabaseKeyKind classifySupabaseKey(String key) {
  final trimmed = key.trim();
  if (trimmed.isEmpty) return SupabaseKeyKind.missing;
  if (trimmed == 'YOUR_PUBLISHABLE_KEY') return SupabaseKeyKind.placeholder;
  if (trimmed.startsWith('sb_publishable_')) return SupabaseKeyKind.publishable;
  if (trimmed.startsWith('sb_secret_')) return SupabaseKeyKind.secret;
  if (trimmed.startsWith('sbp_')) return SupabaseKeyKind.accessToken;
  if (trimmed.startsWith('eyJ')) {
    final role = _jwtRole(trimmed);
    if (role == 'service_role') return SupabaseKeyKind.serviceRole;
    if (role == 'anon') return SupabaseKeyKind.legacyAnon;
  }
  return SupabaseKeyKind.unknown;
}

String? _jwtRole(String key) {
  final parts = key.split('.');
  if (parts.length < 2) return null;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final decoded = jsonDecode(payload);
    if (decoded is Map && decoded['role'] is String) return decoded['role'] as String;
  } catch (_) {
    return null;
  }
  return null;
}
