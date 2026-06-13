import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfege_app/features/auth/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final capturedVerifyBodies = <Map<String, dynamic>>[];

  Future<void> initWithVerifySuccess() async {
    SharedPreferences.setMockInitialValues({});
    capturedVerifyBodies.clear();

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/verify')) {
        capturedVerifyBodies.add(
          jsonDecode(request.body) as Map<String, dynamic>,
        );
        return http.Response(
          jsonEncode({
            'access_token': 'fake-access-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'fake-refresh-token',
            'user': {
              'id': '00000000-0000-0000-0000-000000000000',
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'link.test@example.com',
              'email_confirmed_at': DateTime.now().toUtc().toIso8601String(),
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'app_metadata': <String, dynamic>{},
              'user_metadata': <String, dynamic>{},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(jsonEncode(<String, dynamic>{}), 200,
          headers: {'content-type': 'application/json'});
    });

    await Supabase.initialize(
      url: 'https://project.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: mockClient,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  }

  tearDown(() async {
    await Supabase.instance.dispose();
  });

  test('token_hash link verifies via /verify and confirms the session',
      () async {
    await initWithVerifySuccess();
    final auth = AuthService();

    final result = await auth.handleEmailConfirmationLink(
      Uri.parse(
        'https://axmadjan-777.github.io/solfege_app/'
        '?token_hash=abc123&type=email',
      ),
    );

    expect(result.outcome, EmailLinkOutcome.confirmed);
    expect(capturedVerifyBodies.single['token_hash'], 'abc123');
    expect(capturedVerifyBodies.single['type'], 'email');
    expect(auth.getCurrentSession(), isNotNull);
    expect(auth.isEmailConfirmed, isTrue);
  });

  test('expired link error is parsed without a network call', () async {
    await initWithVerifySuccess();
    final auth = AuthService();

    final result = await auth.handleEmailConfirmationLink(
      Uri.parse(
        'https://axmadjan-777.github.io/solfege_app/'
        '?error=access_denied&error_code=otp_expired'
        '&error_description=Email+link+is+invalid+or+has+expired',
      ),
    );

    expect(result.outcome, EmailLinkOutcome.expired);
    expect(result.message, contains('устарела'));
    expect(capturedVerifyBodies, isEmpty);
  });

  test('url without confirmation params returns none', () async {
    await initWithVerifySuccess();
    final auth = AuthService();

    final result = await auth.handleEmailConfirmationLink(
      Uri.parse('https://axmadjan-777.github.io/solfege_app/'),
    );

    expect(result.outcome, EmailLinkOutcome.none);
    expect(capturedVerifyBodies, isEmpty);
    expect(auth.getCurrentSession(), isNull);
  });
}
