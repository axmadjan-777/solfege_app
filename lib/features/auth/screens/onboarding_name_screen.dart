import 'package:flutter/material.dart';

import '../models/onboarding_data.dart';
import '../widgets/onboarding_scaffold.dart';
import 'onboarding_age_screen.dart';

class OnboardingNameScreen extends StatefulWidget {
  const OnboardingNameScreen({
    super.key,
    required this.onboardingData,
  });

  final OnboardingData onboardingData;

  @override
  State<OnboardingNameScreen> createState() => _OnboardingNameScreenState();
}

class _OnboardingNameScreenState extends State<OnboardingNameScreen> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.onboardingData.displayName,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _goNext() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingAgeScreen(
          onboardingData: widget.onboardingData.copyWith(displayName: name),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Как вас зовут?',
      subtitle: 'Мы будем обращаться к вам по имени в приложении',
      currentStep: 1,
      totalSteps: 3,
      onBack: () => Navigator.of(context).pop(),
      onNext: _goNext,
      canGoNext: _nameController.text.trim().isNotEmpty,
      child: TextField(
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Имя',
          hintText: 'Например, Анна',
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _goNext(),
      ),
    );
  }
}
