import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfege_app/core/supabase/supabase_config.dart';
import 'package:solfege_app/features/auth/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final capturedUris = <Uri>[];

  setUp(() async {
    capturedUris.clear();
    SharedPreferences.setMockInitialValues({});
    final mockClient = MockClient((request) async {
      capturedUris.add(request.url);
      final user = {
        'id': '00000000-0000-0000-0000-000000000000',
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'user@example.com',
        'email_confirmed_at': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      };
      if (request.url.path.endsWith('/token')) {
        return http.Response(
          jsonEncode({
            'access_token': 'fake-access-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'fake-refresh-token',
            'user': user,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/user')) {
        return http.Response(
          jsonEncode(user),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await Supabase.initialize(
      url: 'https://project.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: mockClient,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });

  tearDown(() async {
    await Supabase.instance.dispose();
  });

  test('password reset email uses the production redirect URL', () async {
    await AuthService().resetPassword('user@example.com');

    final recoverUri =
        capturedUris.firstWhere((uri) => uri.path.endsWith('/recover'));
    expect(
      recoverUri.queryParameters['redirect_to'],
      SupabaseConfig.emailRedirectUrl,
    );
  });

  test('recovery links are not mistaken for signup confirmation', () {
    final auth = AuthService();
    final recoveryUri = Uri.parse(
      'https://axmadjan-777.github.io/solfege_app/'
      '#access_token=token&refresh_token=refresh&type=recovery',
    );

    expect(auth.isPasswordRecoveryLink(recoveryUri), isTrue);
    expect(auth.isEmailConfirmationLink(recoveryUri), isFalse);
  });

  test('email change uses the production redirect URL', () async {
    await Supabase.instance.client.auth.setSession('fake-refresh-token');
    capturedUris.clear();

    await AuthService().updateEmail('new.user@example.com');

    final userUri =
        capturedUris.firstWhere((uri) => uri.path.endsWith('/user'));
    expect(
      userUri.queryParameters['redirect_to'],
      SupabaseConfig.emailRedirectUrl,
    );
  });
}
