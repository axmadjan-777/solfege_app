import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/auth/models/musician_level.dart';
import 'package:solfege_app/features/auth/models/onboarding_data.dart';
import 'package:solfege_app/features/auth/models/onboarding_metadata.dart';

void main() {
  test('fromUserMetadata restores onboarding data', () {
    final data = OnboardingMetadata.fromUserMetadata({
      'display_name': 'Анна',
      'age': 14,
      'musician_level': 'beginner',
    });

    expect(data, isNotNull);
    expect(data!.displayName, 'Анна');
    expect(data.age, 14);
    expect(data.musicianLevel, MusicianLevel.beginner);
    expect(data.isComplete, isTrue);
  });

  test('toUserMetadata roundtrip', () {
    const original = OnboardingData(
      displayName: 'Иван',
      age: 20,
      musicianLevel: MusicianLevel.pro,
    );

    final restored = OnboardingMetadata.fromUserMetadata(
      OnboardingMetadata.toUserMetadata(original),
    );

    expect(restored?.displayName, 'Иван');
    expect(restored?.age, 20);
    expect(restored?.musicianLevel, MusicianLevel.pro);
  });
}
