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
}
