import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/core/supabase/supabase_config.dart';

void main() {
  test('publishable and anon keys are sent, secret keys are refused', () {
    expect(classifySupabaseKey('sb_publishable_example'), SupabaseKeyKind.publishable);
    expect(classifySupabaseKey(_jwt('anon')), SupabaseKeyKind.legacyAnon);
    expect(classifySupabaseKey('sb_secret_example'), SupabaseKeyKind.secret);
    expect(classifySupabaseKey(_jwt('service_role')), SupabaseKeyKind.serviceRole);
    expect(classifySupabaseKey('sbp_example'), SupabaseKeyKind.accessToken);
    expect(classifySupabaseKey('YOUR_PUBLISHABLE_KEY'), SupabaseKeyKind.placeholder);
    expect(classifySupabaseKey(''), SupabaseKeyKind.missing);

    expect(SupabaseKeyKind.publishable.isClientSafe, isTrue);
    expect(SupabaseKeyKind.secret.isClientSafe, isFalse);
    expect(SupabaseKeyKind.serviceRole.isClientSafe, isFalse);
    expect(SupabaseKeyKind.accessToken.isClientSafe, isFalse);
  });

  test('a secret key explains the browser 401 before any request', () {
    final message = SupabaseConfig.diagnosticFor(
      key: 'sb_secret_example',
      url: 'https://example.supabase.co',
    );
    expect(message, contains('401'));
    expect(message, contains('publishable'));

    final token = SupabaseConfig.diagnosticFor(
      key: 'sbp_example',
      url: 'https://example.supabase.co',
    );
    expect(token, contains('401'));
    expect(token, contains('sbp_'));
  });
}

String _jwt(String role) {
  String part(Object value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  return '${part({'alg': 'none'})}.${part({'role': role})}.sig';
}
