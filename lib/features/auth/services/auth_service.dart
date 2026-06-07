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
      redirectTo: SupabaseConfig.emailRedirectUrl,
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
    await SupabaseClientProvider.client.auth.signInWithOtp(
      phone: normalized,
      shouldCreateUser: true,
    );
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
    await SupabaseClientProvider.client.auth.signInWithOtp(
      phone: normalized,
      shouldCreateUser: true,
      data: OnboardingMetadata.toUserMetadata(onboardingData),
    );
    return normalized;
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
