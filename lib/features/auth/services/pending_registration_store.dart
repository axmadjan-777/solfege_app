import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding_data.dart';
import '../models/musician_level.dart';

class PendingRegistrationStore {
  const PendingRegistrationStore();

  static const _emailKey = 'pending_registration_email';
  static const _phoneKey = 'pending_registration_phone';
  static const _onboardingKey = 'pending_onboarding_json';
  static const _verifiedShownPrefix = 'email_verified_shown_';
  static const _showVerifiedSuccessPrefix = 'show_verified_success_';

  Future<void> savePending({
    required String email,
    required OnboardingData onboardingData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email.trim());
    await prefs.remove(_phoneKey);
    await prefs.setString(_onboardingKey, jsonEncode(_encode(onboardingData)));
  }

  Future<void> savePendingPhone({
    required String phone,
    required OnboardingData onboardingData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, phone.trim());
    await prefs.remove(_emailKey);
    await prefs.setString(_onboardingKey, jsonEncode(_encode(onboardingData)));
  }

  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_emailKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_onboardingKey);
  }

  Future<String?> getPendingEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  Future<String?> getPendingPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  Future<OnboardingData?> getPendingOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_onboardingKey);
    if (raw == null) return null;
    return _decode(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<bool> hasPendingRegistration() async {
    final email = await getPendingEmail();
    return email != null && email.isNotEmpty;
  }

  Future<bool> hasShownVerifiedSuccess(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_verifiedShownPrefix$userId') ?? false;
  }

  Future<void> markVerifiedSuccessShown(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_verifiedShownPrefix$userId', true);
    await prefs.remove('$_showVerifiedSuccessPrefix$userId');
  }

  Future<void> markShowVerifiedSuccess(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_showVerifiedSuccessPrefix$userId', true);
  }

  Future<bool> shouldShowVerifiedSuccess(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_showVerifiedSuccessPrefix$userId') ?? false;
  }

  Map<String, dynamic> _encode(OnboardingData data) {
    return {
      'displayName': data.displayName,
      'age': data.age,
      'musicianLevel': data.musicianLevel?.dbValue,
    };
  }

  OnboardingData _decode(Map<String, dynamic> json) {
    return OnboardingData(
      displayName: json['displayName'] as String? ?? '',
      age: json['age'] as int?,
      musicianLevel: json['musicianLevel'] == null
          ? null
          : MusicianLevel.fromDb(json['musicianLevel'] as String),
    );
  }
}
