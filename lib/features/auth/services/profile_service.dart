import '../../../core/supabase/supabase_client_provider.dart';
import '../models/gender.dart';
import '../models/onboarding_data.dart';
import '../models/onboarding_metadata.dart';
import '../models/user_profile.dart';
import 'pending_registration_store.dart';

class ProfileService {
  const ProfileService({PendingRegistrationStore? pendingStore})
      : _pendingStore = pendingStore ?? const PendingRegistrationStore();

  final PendingRegistrationStore _pendingStore;

  Future<UserProfile?> getCurrentProfile() async {
    final user = SupabaseClientProvider.client.auth.currentUser;
    if (user == null) return null;

    final data = await SupabaseClientProvider.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<UserProfile> upsertProfile({
    required OnboardingData onboardingData,
    bool onboardingCompleted = true,
    Gender? gender,
    String? authUserId,
  }) async {
    final user = SupabaseClientProvider.client.auth.currentUser;
    if (user == null) {
      throw StateError('Пользователь не авторизован');
    }
    if (authUserId != null && user.id != authUserId) {
      throw StateError('Auth user id не совпадает с текущей сессией');
    }

    if (!onboardingData.isComplete) {
      throw ArgumentError('Onboarding data is incomplete');
    }

    final payload = {
      'id': user.id,
      'display_name': onboardingData.displayName.trim(),
      'age': onboardingData.age!,
      'musician_level': onboardingData.musicianLevel!.dbValue,
      'onboarding_completed': onboardingCompleted,
      'preferred_note_language': 'ru_solfege',
      if (gender != null) 'gender': gender.dbValue,
    };

    final data = await SupabaseClientProvider.client
        .from('profiles')
        .upsert(payload)
        .select()
        .single();

    return UserProfile.fromJson(data);
  }

  Future<UserProfile> ensureCurrentUserProfile({
    OnboardingData? onboardingData,
    String? authUserId,
  }) async {
    final user = SupabaseClientProvider.client.auth.currentUser;
    if (user == null) {
      throw StateError('Пользователь не авторизован');
    }
    if (authUserId != null && user.id != authUserId) {
      throw StateError('Auth user id не совпадает с текущей сессией');
    }

    final existing = await getCurrentProfile();
    if (existing != null && existing.isComplete) {
      return existing;
    }

    final pending = await _pendingStore.getPendingOnboarding();
    final fromMetadata =
        OnboardingMetadata.fromUserMetadata(user.userMetadata);

    final resolved = OnboardingMetadata.merge(
      primary: onboardingData,
      fallback: pending ?? fromMetadata,
      profile: existing,
    );

    if (!resolved.isComplete) {
      throw StateError('Onboarding data is incomplete');
    }

    final hadPending = await _pendingStore.hasPendingRegistration();
    final profile = await upsertProfile(
      onboardingData: resolved,
      authUserId: authUserId ?? user.id,
    );
    if (hadPending) {
      await _pendingStore.markShowVerifiedSuccess(user.id);
    }
    await _pendingStore.clearPending();
    return profile;
  }

  Future<UserProfile> updateEditableFields({
    required String displayName,
    required int age,
    Gender? gender,
  }) async {
    final user = SupabaseClientProvider.client.auth.currentUser;
    if (user == null) {
      throw StateError('Пользователь не авторизован');
    }

    final existing = await getCurrentProfile();
    if (existing == null) {
      throw StateError('Профиль не найден');
    }

    final payload = {
      'display_name': displayName.trim(),
      'age': age,
      if (gender != null) 'gender': gender.dbValue,
    };

    final data = await SupabaseClientProvider.client
        .from('profiles')
        .update(payload)
        .eq('id', user.id)
        .select()
        .single();

    return UserProfile.fromJson(data);
  }

  Future<bool> isOnboardingComplete() async {
    final profile = await getCurrentProfile();
    return profile?.isComplete ?? false;
  }

  Future<UserProfile> updateProfile({
    required OnboardingData onboardingData,
    bool onboardingCompleted = true,
  }) {
    return upsertProfile(
      onboardingData: onboardingData,
      onboardingCompleted: onboardingCompleted,
    );
  }

  OnboardingData incompleteOnboardingData({
    UserProfile? profile,
    OnboardingData? pending,
  }) {
    final user = SupabaseClientProvider.client.auth.currentUser;
    final fromMetadata = user == null
        ? null
        : OnboardingMetadata.fromUserMetadata(user.userMetadata);

    return OnboardingMetadata.merge(
      primary: pending,
      fallback: fromMetadata,
      profile: profile,
    );
  }
}
