import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/onboarding_data.dart';
import '../services/auth_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_auth_button.dart';
import 'phone_otp_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({
    super.key,
    required this.onboardingData,
    this.authService,
  });

  final OnboardingData onboardingData;
  final AuthService? authService;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AuthService _authService = widget.authService ?? AuthService();
  late final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Введите номер телефона';
    if (digits.length < 10) return 'Введите корректный номер телефона';
    return null;
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final normalizedPhone = await _authService.sendPhoneOtp(_phoneController.text);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PhoneOtpScreen(
            phone: normalizedPhone,
            onboardingData: widget.onboardingData,
            authService: _authService,
            isRegistration: false,
          ),
        ),
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
      appBar: AppBar(title: const Text('Вход по телефону')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                AuthTextField(
                  controller: _phoneController,
                  label: 'Телефон',
                  hint: '+7 900 000 00 00',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sendCode(),
                  validator: _validatePhone,
                ),
                const SizedBox(height: 32),
                PrimaryAuthButton(
                  label: 'Отправить код',
                  isLoading: _isLoading,
                  onPressed: _sendCode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
