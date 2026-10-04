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
      url.isNotEmpty &&
      publishableKey.isNotEmpty &&
      publishableKey != 'YOUR_PUBLISHABLE_KEY';

  static String get diagnosticMessage {
    if (publishableKey == 'YOUR_PUBLISHABLE_KEY') {
      return 'In dart_defines.json steht noch die Vorlage YOUR_PUBLISHABLE_KEY. '
          'Trage den echten Publishable Key aus dem Supabase Dashboard → API ein.';
    }
    final missing = <String>[
      if (url.isEmpty) 'SUPABASE_URL',
      if (publishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
    ];
    if (missing.isEmpty) return 'Die Variablen sind gesetzt, die Konfiguration ist aber unvollständig.';
    return 'Nicht erhalten: ${missing.join(', ')}. '
        'Vermutlich sind die --dart-define-Werte nicht in den Build gelangt '
        '(flutter run vollständig neu starten, ohne Leerzeilen im Befehl).';
  }

  static String get configurationHint =>
      'Empfohlen: die Datei dart_defines.json:\n'
      '1. cp dart_defines.example.json dart_defines.json\n'
      '2. Publishable Key in dart_defines.json eintragen\n'
      '3. flutter run -d chrome --dart-define-from-file=dart_defines.json\n\n'
      'Oder in einer Zeile (ohne Leerzeilen zwischen \\\\):\n'
      'SUPABASE_URL und SUPABASE_PUBLISHABLE_KEY per --dart-define übergeben.\n'
      'Beispiel:\n'
      'flutter run -d chrome \\\n'
      '  --dart-define=SUPABASE_URL=$defaultProjectUrl \\\n'
      '  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY';
}
