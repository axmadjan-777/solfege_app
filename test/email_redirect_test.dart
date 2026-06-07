import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfege_app/core/supabase/supabase_config.dart';
import 'package:solfege_app/features/auth/models/musician_level.dart';
import 'package:solfege_app/features/auth/models/onboarding_data.dart';
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
      final path = request.url.path;
      if (path.endsWith('/signup')) {
        return http.Response(
          jsonEncode({
            'id': '00000000-0000-0000-0000-000000000000',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'redirect.test@example.com',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'app_metadata': <String, dynamic>{},
            'user_metadata': <String, dynamic>{},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      // /resend and anything else.
      return http.Response(jsonEncode(<String, dynamic>{}), 200,
          headers: {'content-type': 'application/json'});
    });

    await Supabase.initialize(
      url: 'https://project.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: mockClient,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
      ),
    );
  });

  tearDown(() async {
    await Supabase.instance.dispose();
  });

  test('signUpWithEmail sends production redirect_to', () async {
    final auth = AuthService();
    await auth.signUpWithEmail(
      email: 'redirect.test@example.com',
      password: 'Password123!',
      onboardingData: const OnboardingData(
        displayName: 'Тест',
        age: 25,
        musicianLevel: MusicianLevel.beginner,
      ),
    );

    final signupUri =
        capturedUris.firstWhere((u) => u.path.endsWith('/signup'));
    expect(signupUri.queryParameters['redirect_to'],
        SupabaseConfig.emailRedirectUrl);
    expect(SupabaseConfig.emailRedirectUrl,
        'https://axmadjan-777.github.io/solfege_app/');
    expect(
      signupUri.queryParameters['redirect_to'],
      isNot(contains('localhost')),
    );
  });

  test('resendConfirmationEmail sends production redirect_to', () async {
    final auth = AuthService();
    await auth.resendConfirmationEmail('redirect.test@example.com');

    final resendUri =
        capturedUris.firstWhere((u) => u.path.endsWith('/resend'));
    expect(resendUri.queryParameters['redirect_to'],
        SupabaseConfig.emailRedirectUrl);
    expect(
      resendUri.queryParameters['redirect_to'],
      isNot(contains('localhost')),
    );
  });
}
