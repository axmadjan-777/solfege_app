import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/onboarding_data.dart';
import '../widgets/onboarding_scaffold.dart';
import 'onboarding_level_screen.dart';

class OnboardingAgeScreen extends StatefulWidget {
  const OnboardingAgeScreen({
    super.key,
    required this.onboardingData,
  });

  final OnboardingData onboardingData;

  @override
  State<OnboardingAgeScreen> createState() => _OnboardingAgeScreenState();
}

class _OnboardingAgeScreenState extends State<OnboardingAgeScreen> {
  static const _minAge = 6;
  static const _maxAge = 90;

  late int _selectedAge;

  @override
  void initState() {
    super.initState();
    _selectedAge = widget.onboardingData.age ?? 18;
  }

  void _goNext() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingLevelScreen(
          onboardingData: widget.onboardingData.copyWith(age: _selectedAge),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Сколько вам лет?',
      subtitle: 'Это поможет подобрать подходящий темп обучения',
      currentStep: 2,
      totalSteps: 3,
      onBack: () => Navigator.of(context).pop(),
      onNext: _goNext,
      child: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: _selectedAge - _minAge,
                ),
                itemExtent: 52,
                onSelectedItemChanged: (index) {
                  setState(() => _selectedAge = _minAge + index);
                },
                children: [
                  for (var age = _minAge; age <= _maxAge; age++)
                    Center(
                      child: Text(
                        '$age',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Выбранный возраст: $_selectedAge',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
