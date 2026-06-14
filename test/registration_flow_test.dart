import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfege_app/features/auth/models/musician_level.dart';
import 'package:solfege_app/features/auth/models/onboarding_data.dart';
import 'package:solfege_app/features/auth/services/auth_service.dart';
import 'package:solfege_app/features/auth/services/pending_registration_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// End-to-end логики регистрации по email:
/// регистрация → письмо со ссылкой → клик по ссылке → подтверждение.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = '00000000-0000-0000-0000-000000000000';
  const email = 'newuser@example.com';
  const onboarding = OnboardingData(
    displayName: 'Новый',
    age: 30,
    musicianLevel: MusicianLevel.beginner,
  );

  final paths = <String>[];

  Map<String, dynamic> pendingUserJson() => {
        'id': userId,
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': email,
        // Почта ещё НЕ подтверждена — Supabase прислал письмо и не вернул сессию.
        'email_confirmed_at': null,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      };

  Map<String, dynamic> confirmedUserJson() => {
        ...pendingUserJson(),
        'email_confirmed_at': DateTime.now().toUtc().toIso8601String(),
      };

  Map<String, dynamic> sessionJson() => {
        'access_token': 'fake-access-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'fake-refresh-token',
        'user': confirmedUserJson(),
      };

  Future<void> initWith(AuthFlowType flowType) async {
    SharedPreferences.setMockInitialValues({});
    paths.clear();

    final mockClient = MockClient((request) async {
      final path = request.url.path;
      paths.add(path);

      // Регистрация с включённым подтверждением: сессии нет, только пользователь.
      if (path.endsWith('/signup')) {
        return http.Response(jsonEncode(pendingUserJson()), 200,
            headers: {'content-type': 'application/json'});
      }
      // Кастомный шаблон письма (token_hash) → verifyOTP.
      if (path.endsWith('/verify')) {
        return http.Response(jsonEncode(sessionJson()), 200,
            headers: {'content-type': 'application/json'});
      }
      // Стандартное письмо (implicit) → getSessionFromUrl → GET /user.
      if (path.endsWith('/user')) {
        return http.Response(jsonEncode(confirmedUserJson()), 200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(jsonEncode(<String, dynamic>{}), 200,
          headers: {'content-type': 'application/json'});
    });

    await Supabase.initialize(
      url: 'https://project.supabase.co',
      publishableKey: 'test-publishable-key',
      httpClient: mockClient,
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: false,
        authFlowType: flowType,
      ),
    );
  }

  tearDown(() async {
    await Supabase.instance.dispose();
  });

  test('register → pending email saved → token_hash link confirms', () async {
    await initWith(AuthFlowType.pkce);
    final auth = AuthService();
    const store = PendingRegistrationStore();

    // 1. Регистрация: сессии нет, данные кладутся в pending.
    final signUp = await auth.signUpWithEmail(
      email: email,
      password: 'Password123!',
      onboardingData: onboarding,
    );
    expect(signUp.session, isNull);
    expect(auth.getCurrentSession(), isNull);
    expect(await store.getPendingEmail(), email);

    // 2. Клик по ссылке из письма (кастомный шаблон с token_hash).
    final result = await auth.handleEmailConfirmationLink(
      Uri.parse(
        'https://axmadjan-777.github.io/solfege_app/'
        '?token_hash=hash-123&type=email',
      ),
    );

    // 3. Подтверждение прошло, сессия создана, почта подтверждена.
    expect(result.outcome, EmailLinkOutcome.confirmed);
    expect(auth.getCurrentSession(), isNotNull);
    expect(auth.isEmailConfirmed, isTrue);
    expect(paths, contains('/auth/v1/signup'));
    expect(paths, contains('/auth/v1/verify'));
  });

  test('register → standard implicit link confirms on any device', () async {
    await initWith(AuthFlowType.implicit);
    final auth = AuthService();

    final signUp = await auth.signUpWithEmail(
      email: email,
      password: 'Password123!',
      onboardingData: onboarding,
    );
    expect(signUp.session, isNull);

    // Стандартное письмо после серверной проверки возвращает токены во фрагменте.
    final link = Uri.parse(
      'https://axmadjan-777.github.io/solfege_app/'
      '#access_token=fake-access-token&refresh_token=fake-refresh-token'
      '&expires_in=3600&token_type=bearer&type=signup',
    );
    expect(auth.isEmailConfirmationLink(link), isTrue);

    final result = await auth.handleEmailConfirmationLink(link);
    expect(result.outcome, EmailLinkOutcome.confirmed);
    expect(auth.getCurrentSession(), isNotNull);
    expect(auth.isEmailConfirmed, isTrue);
  });

  test('expired link is recognised from query params', () async {
    await initWith(AuthFlowType.implicit);
    final auth = AuthService();

    final result = await auth.handleEmailConfirmationLink(
      Uri.parse(
        'https://axmadjan-777.github.io/solfege_app/'
        '#error=access_denied&error_code=otp_expired'
        '&error_description=Email+link+is+invalid+or+has+expired',
      ),
    );
    expect(result.outcome, EmailLinkOutcome.expired);
    expect(auth.getCurrentSession(), isNull);
  });
}
