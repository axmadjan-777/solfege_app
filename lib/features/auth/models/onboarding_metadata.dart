import 'musician_level.dart';
import 'onboarding_data.dart';
import 'user_profile.dart';

abstract final class OnboardingMetadata {
  static const displayNameKey = 'display_name';
  static const ageKey = 'age';
  static const musicianLevelKey = 'musician_level';

  static Map<String, dynamic> toUserMetadata(OnboardingData data) {
    return {
      displayNameKey: data.displayName.trim(),
      if (data.age != null) ageKey: data.age,
      if (data.musicianLevel != null)
        musicianLevelKey: data.musicianLevel!.dbValue,
    };
  }

  static OnboardingData? fromUserMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) return null;

    final displayName = metadata[displayNameKey] as String? ?? '';
    final ageRaw = metadata[ageKey];
    final age = switch (ageRaw) {
      final int value => value,
      final String value => int.tryParse(value),
      _ => null,
    };
    final levelRaw = metadata[musicianLevelKey] as String?;

    return OnboardingData(
      displayName: displayName,
      age: age,
      musicianLevel:
          levelRaw == null ? null : MusicianLevel.fromDb(levelRaw),
    );
  }

  static OnboardingData merge({
    OnboardingData? primary,
    OnboardingData? fallback,
    UserProfile? profile,
  }) {
    final fromProfile = profile == null
        ? const OnboardingData()
        : OnboardingData(
            displayName: profile.displayName,
            age: profile.age,
            musicianLevel: profile.musicianLevel,
          );

    return OnboardingData(
      displayName: _firstNonEmpty([
        primary?.displayName,
        fallback?.displayName,
        fromProfile.displayName,
      ]),
      age: primary?.age ?? fallback?.age ?? fromProfile.age,
      musicianLevel:
          primary?.musicianLevel ?? fallback?.musicianLevel ?? fromProfile.musicianLevel,
    );
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
}
