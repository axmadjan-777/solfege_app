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
    this.initialMessage,
  });

  final String email;
  final OnboardingData onboardingData;
  final AuthService? authService;
  final VoidCallback? onConfirmed;

  /// Сообщение, которое нужно показать сразу при открытии экрана
  /// (например, «ссылка устарела»).
  final String? initialMessage;

  @override
  State<EmailVerificationPendingScreen> createState() =>
      _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState
    extends State<EmailVerificationPendingScreen> {
  static const _resendCooldownSeconds = 60;

  late final AuthService _authService = widget.authService ?? AuthService();
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _cooldownTimer;
  bool _isChecking = false;
  bool _isResending = false;
  int _resendSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    final message = widget.initialMessage;
    if (message != null && message.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      });
    }
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
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConfirmed({bool silent = false}) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      final session = _authService.getCurrentSession();

      // Без активной сессии обновлять и перезапрашивать нечего: подтверждение
      // в другом окне не попадает в это окно автоматически.
      if (session == null) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Откройте ссылку из письма — подтверждение произойдёт '
                'автоматически. Если письмо открыто на другом устройстве, '
                'войдите в приложение заново.',
              ),
            ),
          );
        }
        return;
      }

      await _authService.refreshSession();
      final user = await _authService.reloadUser();

      if (user?.emailConfirmedAt != null) {
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

  Future<void> _resend() async {
    if (_isResending || _resendSecondsLeft > 0) return;
    final email = widget.email.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не знаем, на какой адрес отправлять. Зарегистрируйтесь заново.',
          ),
        ),
      );
      return;
    }

    setState(() => _isResending = true);
    try {
      await _authService.resendConfirmationEmail(email);
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Новое письмо отправлено на $email.')),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendSecondsLeft = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSecondsLeft -= 1;
        if (_resendSecondsLeft <= 0) timer.cancel();
      });
    });
  }

  String get _resendLabel => _resendSecondsLeft > 0
      ? 'Отправить письмо снова ($_resendSecondsLeft)'
      : 'Отправить письмо снова';

  @override
  Widget build(BuildContext context) {
    final canResend =
        !_isResending && _resendSecondsLeft == 0 && widget.email.trim().isNotEmpty;
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
                widget.email.trim().isEmpty
                    ? 'Откройте ссылку из письма, чтобы подтвердить почту.'
                    : 'Мы отправили ссылку на ${widget.email}. '
                        'Откройте её — подтверждение произойдёт автоматически.',
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
              const SizedBox(height: 12),
              TextButton(
                onPressed: canResend ? _resend : null,
                child: _isResending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_resendLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
