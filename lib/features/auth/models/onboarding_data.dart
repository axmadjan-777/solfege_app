import 'musician_level.dart';

class OnboardingData {
  const OnboardingData({
    this.displayName = '',
    this.age,
    this.musicianLevel,
  });

  final String displayName;
  final int? age;
  final MusicianLevel? musicianLevel;

  bool get hasName => displayName.trim().isNotEmpty;
  bool get hasAge => age != null && age! >= 6 && age! <= 90;
  bool get hasLevel => musicianLevel != null;
  bool get isComplete => hasName && hasAge && hasLevel;

  OnboardingData copyWith({
    String? displayName,
    int? age,
    MusicianLevel? musicianLevel,
  }) {
    return OnboardingData(
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      musicianLevel: musicianLevel ?? this.musicianLevel,
    );
  }
}
