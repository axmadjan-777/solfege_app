import 'gender.dart';
import 'musician_level.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.age,
    required this.musicianLevel,
    required this.onboardingCompleted,
    this.gender,
    this.preferredNoteLanguage = 'ru_solfege',
  });

  final String id;
  final String displayName;
  final int? age;
  final MusicianLevel? musicianLevel;
  final bool onboardingCompleted;
  final Gender? gender;
  final String preferredNoteLanguage;

  bool get isComplete =>
      onboardingCompleted &&
      displayName.trim().isNotEmpty &&
      age != null &&
      age! >= 6 &&
      age! <= 90 &&
      musicianLevel != null;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final levelRaw = json['musician_level'] as String?;
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? '',
      age: json['age'] as int?,
      musicianLevel: levelRaw == null ? null : MusicianLevel.fromDb(levelRaw),
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      gender: Gender.fromDb(json['gender'] as String?),
      preferredNoteLanguage:
          json['preferred_note_language'] as String? ?? 'ru_solfege',
    );
  }

  Map<String, dynamic> toJson({bool? onboardingCompleted}) {
    return {
      'id': id,
      'display_name': displayName,
      if (age != null) 'age': age,
      if (musicianLevel != null) 'musician_level': musicianLevel!.dbValue,
      'onboarding_completed': onboardingCompleted ?? this.onboardingCompleted,
      'preferred_note_language': preferredNoteLanguage,
      if (gender != null) 'gender': gender!.dbValue,
    };
  }

  UserProfile copyWith({
    String? displayName,
    int? age,
    Gender? gender,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      musicianLevel: musicianLevel,
      onboardingCompleted: onboardingCompleted,
      gender: gender ?? this.gender,
      preferredNoteLanguage: preferredNoteLanguage,
    );
  }
}
