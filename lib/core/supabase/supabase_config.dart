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

  /// URL пользователя возвращается после клика по ссылке из письма
  /// (подтверждение email / сброс пароля). По умолчанию — задеплоенный
  /// GitHub Pages билд, чтобы ссылки не вели на localhost. Можно переопределить
  /// через `--dart-define=SUPABASE_REDIRECT_URL=...`.
  static const _redirectOverride =
      String.fromEnvironment('SUPABASE_REDIRECT_URL');

  static const deployedWebUrl = 'https://axmadjan-777.github.io/solfege_app/';

  static String get emailRedirectUrl =>
      _redirectOverride.isNotEmpty ? _redirectOverride : deployedWebUrl;

  static bool get isConfigured =>
      url.isNotEmpty &&
      publishableKey.isNotEmpty &&
      publishableKey != 'YOUR_PUBLISHABLE_KEY';

  static String get diagnosticMessage {
    if (publishableKey == 'YOUR_PUBLISHABLE_KEY') {
      return 'В dart_defines.json остался шаблон YOUR_PUBLISHABLE_KEY. '
          'Вставьте настоящий publishable key из Supabase Dashboard → API.';
    }
    final missing = <String>[
      if (url.isEmpty) 'SUPABASE_URL',
      if (publishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
    ];
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
