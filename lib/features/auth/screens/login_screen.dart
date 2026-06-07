import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/onboarding_data.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_auth_button.dart';
import 'forgot_password_screen.dart';
import 'onboarding_name_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onboardingData,
    this.authService,
    this.profileService,
    this.initialEmail = '',
  });

  final OnboardingData onboardingData;
  final AuthService? authService;
  final ProfileService? profileService;
  final String initialEmail;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AuthService _authService = widget.authService ?? AuthService();
  late final ProfileService _profileService =
      widget.profileService ?? const ProfileService();
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail);
  late final TextEditingController _passwordController =
      TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      try {
        await _profileService.ensureCurrentUserProfile(
          onboardingData: widget.onboardingData.isComplete
              ? widget.onboardingData
              : null,
        );
      } on StateError {
        final profile = await _profileService.getCurrentProfile();
        final data = _profileService.incompleteOnboardingData(
          profile: profile,
          pending: widget.onboardingData.isComplete
              ? widget.onboardingData
              : null,
        );

        if (!data.isComplete) {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => OnboardingNameScreen(onboardingData: data),
            ),
            (route) => false,
          );
          return;
        }
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                AuthTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Введите email';
                    if (!email.contains('@') || !email.contains('.')) {
                      return 'Введите корректный email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _passwordController,
                  label: 'Пароль',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  validator: (value) {
                    if ((value ?? '').isEmpty) return 'Введите пароль';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ForgotPasswordScreen(
                            authService: _authService,
                            initialEmail: _emailController.text,
                          ),
                        ),
                      );
                    },
                    child: const Text('Забыли пароль?'),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryAuthButton(
                  label: 'Войти',
                  isLoading: _isLoading,
                  onPressed: _login,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
