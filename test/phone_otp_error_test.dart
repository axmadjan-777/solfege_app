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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final capturedOtpBodies = <Map<String, dynamic>>[];
  late int otpStatus;
  late Map<String, dynamic> otpErrorBody;

  Future<void> initWithOtpResponse() async {
    SharedPreferences.setMockInitialValues({});
    capturedOtpBodies.clear();

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/otp')) {
        capturedOtpBodies.add(
          jsonDecode(request.body) as Map<String, dynamic>,
        );
        return http.Response(
          jsonEncode(otpErrorBody),
          otpStatus,
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

  const onboarding = OnboardingData(
    displayName: 'Тест',
    age: 25,
    musicianLevel: MusicianLevel.beginner,
  );

  test('sms_send_failed surfaces actionable error and clears pending', () async {
    otpStatus = 422;
    otpErrorBody = {
      'code': 422,
      'error_code': 'sms_send_failed',
      'msg': 'Error sending confirmation OTP to provider: invalid number',
    };
    await initWithOtpResponse();

    final auth = AuthService();
    AuthException? thrown;
    try {
      await auth.sendPhoneOtpForRegistration(
        phone: '+79990000000',
        onboardingData: onboarding,
      );
    } on AuthException catch (e) {
      thrown = e;
    }

    expect(thrown, isNotNull);
    expect(thrown!.message, contains('Не удалось отправить SMS'));
    expect(thrown.message, contains('Verified Caller IDs'));
    // Исходная причина сохранена для отладки.
    expect(thrown.message, contains('provider'));

    // Запрос реально ушёл с shouldCreateUser + метаданными onboarding.
    expect(capturedOtpBodies.single['create_user'], isTrue);
    final data = capturedOtpBodies.single['data'] as Map<String, dynamic>;
    expect(data['display_name'], 'Тест');
    expect(data['age'], 25);
    expect(data['musician_level'], 'beginner');

    // «Висящий» pending очищен после неудачной отправки.
    const store = PendingRegistrationStore();
    expect(await store.getPendingPhone(), isNull);
  });

  test('rate limit maps to a wait-and-retry message', () async {
    otpStatus = 429;
    otpErrorBody = {
      'code': 429,
      'error_code': 'over_sms_send_rate_limit',
      'msg': 'sms rate limit exceeded',
    };
    await initWithOtpResponse();

    final auth = AuthService();
    AuthException? thrown;
    try {
      await auth.sendPhoneOtpForRegistration(
        phone: '+79990000000',
        onboardingData: onboarding,
      );
    } on AuthException catch (e) {
      thrown = e;
    }

    expect(thrown, isNotNull);
    expect(thrown!.message, contains('Слишком много попыток'));
  });
}
