import 'package:flutter/material.dart';

import '../models/musician_level.dart';
import '../models/onboarding_data.dart';
import '../widgets/musician_level_card.dart';
import '../widgets/onboarding_scaffold.dart';
import 'auth_screen.dart';

class OnboardingLevelScreen extends StatefulWidget {
  const OnboardingLevelScreen({
    super.key,
    required this.onboardingData,
  });

  final OnboardingData onboardingData;

  @override
  State<OnboardingLevelScreen> createState() => _OnboardingLevelScreenState();
}

class _OnboardingLevelScreenState extends State<OnboardingLevelScreen> {
  MusicianLevel? _selectedLevel = MusicianLevel.beginner;

  void _goNext() {
    if (_selectedLevel == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AuthScreen(
          onboardingData: widget.onboardingData.copyWith(
            musicianLevel: _selectedLevel,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Ваш уровень',
      subtitle: 'Выберите вариант, который лучше всего описывает ваш опыт',
      currentStep: 3,
      totalSteps: 3,
      nextLabel: 'Продолжить',
      onBack: () => Navigator.of(context).pop(),
      onNext: _goNext,
      canGoNext: _selectedLevel != null,
      child: ListView.separated(
        itemCount: MusicianLevel.values.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final level = MusicianLevel.values[index];
          return MusicianLevelCard(
            level: level,
            isSelected: _selectedLevel == level,
            onTap: () => setState(() => _selectedLevel = level),
          );
        },
      ),
    );
  }
}
