import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/onboarding_data.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'phone_login_screen.dart';
import 'phone_register_screen.dart';
import 'register_screen.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({
    super.key,
    required this.onboardingData,
    this.authService,
  });

  final OnboardingData onboardingData;
  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    final authService = this.authService ?? AuthService();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Почти готово, ${onboardingData.displayName}!',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Создайте аккаунт или войдите, чтобы сохранить прогресс',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RegisterScreen(
                          onboardingData: onboardingData,
                          authService: authService,
                        ),
                      ),
                    );
                  },
                  child: const Text('Создать аккаунт'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LoginScreen(
                          onboardingData: onboardingData,
                          authService: authService,
                        ),
                      ),
                    );
                  },
                  child: const Text('Уже есть аккаунт? Войти'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PhoneRegisterScreen(
                          onboardingData: onboardingData,
                          authService: authService,
                        ),
                      ),
                    );
                  },
                  child: const Text('Регистрация по телефону'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PhoneLoginScreen(
                          onboardingData: onboardingData,
                          authService: authService,
                        ),
                      ),
                    );
                  },
                  child: const Text('Вход по телефону'),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
