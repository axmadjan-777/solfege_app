import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import '../widgets/primary_auth_button.dart';
import '../models/onboarding_data.dart';

class EmailVerificationPendingScreen extends StatefulWidget {
  const EmailVerificationPendingScreen({
    super.key,
    required this.email,
    this.onboardingData = const OnboardingData(),
    this.authService,
    this.onConfirmed,
  });

  final String email;
  final OnboardingData onboardingData;
  final AuthService? authService;
  final VoidCallback? onConfirmed;

  @override
  State<EmailVerificationPendingScreen> createState() =>
      _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState
    extends State<EmailVerificationPendingScreen> {
  late final AuthService _authService = widget.authService ?? AuthService();
  StreamSubscription<AuthState>? _authSubscription;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authService.authStateChanges.listen((event) {
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed) {
        _checkConfirmed(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConfirmed({bool silent = false}) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      await _authService.refreshSession();
      final user = await _authService.reloadUser();
      final session = _authService.getCurrentSession();

      if (user?.emailConfirmedAt != null && session != null) {
        widget.onConfirmed?.call();
        return;
      }

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email ещё не подтверждён. Откройте ссылку в письме и попробуйте снова.',
            ),
          ),
        );
      }
    } on AuthException catch (error) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Подтвердите email',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Мы отправили ссылку на ${widget.email}. '
                'Подтвердите почту, затем нажмите кнопку ниже.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const Spacer(),
              PrimaryAuthButton(
                label: 'Я подтвердил email',
                onPressed: _isChecking ? null : () => _checkConfirmed(),
                isLoading: _isChecking,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
