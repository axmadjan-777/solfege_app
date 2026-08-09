import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfege_app/features/auth/models/musician_level.dart';
import 'package:solfege_app/features/auth/models/onboarding_data.dart';
import 'package:solfege_app/features/auth/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const onboarding = OnboardingData(
    displayName: 'Тест',
    age: 25,
    musicianLevel: MusicianLevel.beginner,
  );

  tearDown(() async {
    await Supabase.instance.dispose();
  });

  test('email rate limit explains that Supabase did not create an account',
      () async {
    SharedPreferences.setMockInitialValues({});
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'code': 429,
          'error_code': 'over_email_send_rate_limit',
          'msg': 'email rate limit exceeded',
        }),
        429,
        headers: {'content-type': 'application/json'},
      );
    });
    await Supabase.initialize(
      url: 'https://project.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: mockClient,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );

    AuthException? thrown;
    try {
      await AuthService().signUpWithEmail(
        email: 'new.user@gmail.com',
        password: 'Password123!',
        onboardingData: onboarding,
      );
    } on AuthException catch (error) {
      thrown = error;
    }

    expect(thrown, isNotNull);
    expect(thrown!.message, contains('аккаунт не создан'));
    expect(thrown.message, contains('2 письма в час'));
    expect(thrown.message, contains('SMTP'));
  });

  test('database signup failure points to Auth logs and profile trigger',
      () async {
    SharedPreferences.setMockInitialValues({});
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'code': 500,
          'error_code': 'unexpected_failure',
          'msg': 'Database error saving new user',
        }),
        500,
        headers: {'content-type': 'application/json'},
      );
    });
    await Supabase.initialize(
      url: 'https://project.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: mockClient,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );

    AuthException? thrown;
    try {
      await AuthService().signUpWithEmail(
        email: 'new.user@gmail.com',
        password: 'Password123!',
        onboardingData: onboarding,
      );
    } on AuthException catch (error) {
      thrown = error;
    }

    expect(thrown, isNotNull);
    expect(thrown!.message, contains('аккаунт не создан'));
    expect(thrown.message, contains('Auth logs'));
    expect(thrown.message, contains('handle_new_user'));
  });

  test('email sign-in creates a session before profile resolution', () async {
    SharedPreferences.setMockInitialValues({});
    var profileRequested = false;
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/token')) {
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
              'email': 'returning.user@gmail.com',
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
      if (request.url.path.contains('/profiles')) {
        profileRequested = true;
      }
      return http.Response(
        jsonEncode(<dynamic>[]),
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

    final response = await AuthService().signInWithEmail(
      email: 'returning.user@gmail.com',
      password: 'Password123!',
    );

    expect(response.session, isNotNull);
    expect(profileRequested, isFalse);
  });
}
