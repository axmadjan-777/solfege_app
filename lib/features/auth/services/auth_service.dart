import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../models/onboarding_data.dart';
import '../models/onboarding_metadata.dart';
import 'pending_registration_store.dart';
import 'profile_service.dart';

class AuthService {
  AuthService({
    ProfileService? profileService,
    PendingRegistrationStore? pendingStore,
  })  : _profileService = profileService ?? const ProfileService(),
        _pendingStore = pendingStore ?? const PendingRegistrationStore();

  final ProfileService _profileService;
  final PendingRegistrationStore _pendingStore;

  Stream<AuthState> get authStateChanges =>
      SupabaseClientProvider.client.auth.onAuthStateChange;

  User? getCurrentUser() => SupabaseClientProvider.client.auth.currentUser;

  Session? getCurrentSession() =>
      SupabaseClientProvider.client.auth.currentSession;

  bool get isEmailConfirmed {
    final user = getCurrentUser();
    return user?.emailConfirmedAt != null;
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required OnboardingData onboardingData,
  }) async {
    final response = await SupabaseClientProvider.client.auth.signUp(
      email: email.trim(),
      password: password,
      data: OnboardingMetadata.toUserMetadata(onboardingData),
      emailRedirectTo: SupabaseConfig.emailRedirectUrl,
    );

    if (response.session != null) {
      await _profileService.ensureCurrentUserProfile(
        onboardingData: onboardingData,
        authUserId: response.user?.id,
      );
      await _pendingStore.clearPending();
    } else {
      await _pendingStore.savePending(
        email: email,
        onboardingData: onboardingData,
      );
    }

    return response;
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await SupabaseClientProvider.client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (response.session != null) {
      await _profileService.ensureCurrentUserProfile(
        authUserId: response.user?.id,
      );
    }

    return response;
  }

  Future<void> resetPassword(String email) {
    return SupabaseClientProvider.client.auth.resetPasswordForEmail(
      email.trim(),
    );
  }

  Future<void> resendConfirmationEmail(String email) {
    return SupabaseClientProvider.client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: SupabaseConfig.emailRedirectUrl,
    );
  }

  String normalizePhone(String phone) => _normalizePhone(phone);

  Future<String> sendPhoneOtp(String phone) async {
    final normalized = _normalizePhone(phone);
    try {
      await SupabaseClientProvider.client.auth.signInWithOtp(
        phone: normalized,
        shouldCreateUser: true,
      );
    } on AuthException catch (error) {
      throw _mapPhoneOtpError(error);
    }
    return normalized;
  }

  Future<String> sendPhoneOtpForRegistration({
    required String phone,
    required OnboardingData onboardingData,
  }) async {
    final normalized = _normalizePhone(phone);
    await _pendingStore.savePendingPhone(
      phone: normalized,
      onboardingData: onboardingData,
    );
    try {
      await SupabaseClientProvider.client.auth.signInWithOtp(
        phone: normalized,
        shouldCreateUser: true,
        data: OnboardingMetadata.toUserMetadata(onboardingData),
      );
    } on AuthException catch (error) {
      // SMS-провайдер откатывает всю транзакцию регистрации, поэтому при сбое
      // пользователь не создаётся в auth.users. Не оставляем «висящий» pending
      // и показываем понятную причину.
      await _pendingStore.clearPending();
      throw _mapPhoneOtpError(error);
    }
    return normalized;
  }

  /// Переводит ошибки отправки SMS-кода в понятные сообщения. Когда SMS не
  /// уходит (Twilio/провайдер, лимиты, выключенная регистрация), Supabase
  /// откатывает создание пользователя — это и есть причина «юзер не появляется
  /// в auth.users» при телефонной регистрации.
  AuthException _mapPhoneOtpError(AuthException error) {
    final code = error.code;
    final message = error.message;
    final lowerMessage = message.toLowerCase();

    final isRateLimit = code == 'over_sms_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        error.statusCode == '429' ||
        lowerMessage.contains('rate limit');
    if (isRateLimit) {
      return AuthException(
        'Слишком много попыток отправки SMS. Подождите и попробуйте позже '
        '(лимиты SMS настраиваются в Supabase → Authentication → Rate Limits). '
        'Детали: $message',
        statusCode: error.statusCode,
        code: code,
      );
    }

    final isSignupDisabled = code == 'signup_disabled' ||
        lowerMessage.contains('signups not allowed') ||
        lowerMessage.contains('signup is disabled');
    if (isSignupDisabled) {
      return AuthException(
        'Регистрация новых пользователей отключена. Включите её в Supabase → '
        'Authentication → Sign In / Providers (Allow new users to sign up). '
        'Детали: $message',
        statusCode: error.statusCode,
        code: code,
      );
    }

    final isSmsSendFailure = code == 'sms_send_failed' ||
        lowerMessage.contains('error sending') ||
        lowerMessage.contains('provider') ||
        lowerMessage.contains('sms');
    if (isSmsSendFailure) {
      return AuthException(
        'Не удалось отправить SMS с кодом, поэтому аккаунт не создан. '
        'Проверьте SMS-провайдера в Supabase (Authentication → Providers → '
        'Phone): на trial-аккаунте Twilio номер получателя должен быть в '
        'Verified Caller IDs, а ключи/Messaging Service SID — корректными. '
        'Детали: $message',
        statusCode: error.statusCode,
        code: code,
      );
    }

    return error;
  }

  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String code,
    OnboardingData? onboardingData,
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    final response = await SupabaseClientProvider.client.auth.verifyOTP(
      phone: normalizedPhone,
      token: code.trim(),
      type: OtpType.sms,
    );

    final authUser = response.user;
    final session = response.session;
    if (authUser == null || session == null) {
      throw const AuthException(
        'Сессия не создана. Проверьте код и повторите попытку.',
      );
    }

    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const AuthException('Auth session не содержит refresh token.');
    }
    await SupabaseClientProvider.client.auth.setSession(
      refreshToken,
      accessToken: session.accessToken,
    );
    await SupabaseClientProvider.client.auth.getUser();

    final currentUser = getCurrentUser();
    final currentSession = getCurrentSession();
    if (currentUser == null ||
        currentSession == null ||
        currentUser.id != authUser.id) {
      throw const AuthException(
        'Не удалось установить auth session после OTP.',
      );
    }

    final pendingOnboarding = await _pendingStore.getPendingOnboarding();
    final resolvedOnboarding = onboardingData ??
        (pendingOnboarding?.isComplete == true ? pendingOnboarding : null);

    if (resolvedOnboarding != null && resolvedOnboarding.isComplete) {
      await SupabaseClientProvider.client.auth.updateUser(
        UserAttributes(
          data: OnboardingMetadata.toUserMetadata(resolvedOnboarding),
        ),
      );
      await _profileService.ensureCurrentUserProfile(
        onboardingData: resolvedOnboarding,
        authUserId: authUser.id,
      );
    } else {
      await _profileService.ensureCurrentUserProfile(authUserId: authUser.id);
    }

    await _pendingStore.clearPending();
    return response;
  }

  Future<User?> reloadUser() async {
    final response = await SupabaseClientProvider.client.auth.getUser();
    return response.user;
  }

  Future<void> refreshSession() async {
    final response = await SupabaseClientProvider.client.auth.refreshSession();
    if (response.session != null) {
      await _profileService.ensureCurrentUserProfile(
        authUserId: response.user?.id,
      );
    }
  }

  Future<void> updateEmail(String newEmail) async {
    await SupabaseClientProvider.client.auth.updateUser(
      UserAttributes(email: newEmail.trim()),
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await SupabaseClientProvider.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signOut() async {
    await SupabaseClientProvider.client.auth.signOut();
    await _pendingStore.clearPending();
  }

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return phone.trim();
    if (phone.trim().startsWith('+')) return '+$digits';
    if (digits.length == 11 && digits.startsWith('8')) {
      return '+7${digits.substring(1)}';
    }
    if (digits.length == 10) return '+7$digits';
    return '+$digits';
  }
}
