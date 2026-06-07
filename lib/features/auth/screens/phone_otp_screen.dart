import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/onboarding_data.dart';
import '../services/auth_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_auth_button.dart';

class PhoneOtpScreen extends StatefulWidget {
  const PhoneOtpScreen({
    super.key,
    required this.phone,
    required this.onboardingData,
    this.authService,
    this.isRegistration = false,
  });

  final String phone;
  final OnboardingData onboardingData;
  final AuthService? authService;
  final bool isRegistration;

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AuthService _authService = widget.authService ?? AuthService();
  late final TextEditingController _codeController = TextEditingController();
  Timer? _countdownTimer;
  int _secondsLeft = 0;
  bool _isVerifying = false;
  bool _isResending = false;

  bool get _canResend => _secondsLeft == 0 && !_isResending;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _secondsLeft = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
        return;
      }
      if (mounted) setState(() => _secondsLeft -= 1);
    });
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() => _isResending = true);
    try {
      await _authService.sendPhoneOtp(widget.phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Код отправлен повторно.')),
      );
      _startCountdown();
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isVerifying = true);
    try {
      await _authService.verifyPhoneOtp(
        phone: widget.phone,
        code: _codeController.text,
        onboardingData:
            widget.isRegistration ? widget.onboardingData : null,
      );

      if (_authService.getCurrentSession() == null ||
          _authService.getCurrentUser() == null) {
        throw const AuthException(
          'Не удалось войти. Проверьте код и повторите попытку.',
        );
      }

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добро пожаловать!')),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Подтверждение телефона')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Введите код из SMS',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Код отправлен на ${widget.phone}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                AuthTextField(
                  controller: _codeController,
                  label: 'Код',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _verify(),
                  validator: (value) {
                    if ((value ?? '').trim().length < 4) {
                      return 'Введите код из SMS';
                    }
                    return null;
                  },
                ),
                const Spacer(),
                PrimaryAuthButton(
                  label: 'Подтвердить',
                  isLoading: _isVerifying,
                  onPressed: _verify,
                ),
                const SizedBox(height: 12),
                PrimaryAuthButton(
                  label: _canResend
                      ? 'Отправить код ещё раз'
                      : 'Повторная отправка через $_secondsLeft с',
                  onPressed: _canResend ? _resend : null,
                  isLoading: _isResending,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
