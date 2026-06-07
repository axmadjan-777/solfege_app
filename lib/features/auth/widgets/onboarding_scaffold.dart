import 'package:flutter/material.dart';

import 'onboarding_progress.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.currentStep,
    required this.totalSteps,
    required this.child,
    required this.onBack,
    required this.onNext,
    this.nextLabel = 'Далее',
    this.canGoNext = true,
    this.isLoading = false,
  });

  final String title;
  final String subtitle;
  final int currentStep;
  final int totalSteps;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  final bool canGoNext;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OnboardingProgress(
                currentStep: currentStep,
                totalSteps: totalSteps,
              ),
              const SizedBox(height: 32),
              Text(title, style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                    ),
              ),
              const SizedBox(height: 32),
              Expanded(child: child),
              Row(
                children: [
                  if (onBack != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading ? null : onBack,
                        child: const Text('Назад'),
                      ),
                    ),
                  if (onBack != null) const SizedBox(width: 12),
                  Expanded(
                    flex: onBack != null ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: (canGoNext && !isLoading) ? onNext : null,
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(nextLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
