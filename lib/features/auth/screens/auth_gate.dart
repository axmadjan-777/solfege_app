import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../app/main_shell_screen.dart';
import '../models/onboarding_data.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/pending_registration_store.dart';
import '../services/profile_service.dart';
import 'email_verification_pending_screen.dart';
import 'email_verified_success_screen.dart';
import 'onboarding_name_screen.dart';
import 'supabase_config_error_screen.dart';
import 'welcome_screen.dart';

enum _GateState {
  loading,
  verifyingEmailLink,
  configError,
  unauthenticated,
  awaitingEmailConfirmation,
  emailVerifiedSuccess,
  incompleteProfile,
  ready,
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.authService,
    this.profileService,
    this.pendingStore,
  });

  final AuthService? authService;
  final ProfileService? profileService;
  final PendingRegistrationStore? pendingStore;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService = widget.authService ?? AuthService();
  late final ProfileService _profileService =
      widget.profileService ?? const ProfileService();
  late final PendingRegistrationStore _pendingStore =
      widget.pendingStore ?? const PendingRegistrationStore();

  _GateState _state = _GateState.loading;
  StreamSubscription<AuthState>? _authSubscription;
  String? _pendingEmail;
  String? _linkMessage;
  OnboardingData _incompleteOnboarding = const OnboardingData();
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!SupabaseConfig.isConfigured) {
      setState(() => _state = _GateState.configError);
      return;
    }

    // Если сессии ещё нет, а в адресе пришла ссылка подтверждения — завершаем
    // подтверждение до выбора экрана, чтобы переход по ссылке сразу вёл к успеху,
    // а не к экрану «Подтвердите email».
    if (_authService.getCurrentSession() == null) {
      await _handleConfirmationLink();
    }

    _authSubscription = _authService.authStateChanges.listen((event) {
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed ||
          event.event == AuthChangeEvent.signedOut) {
        _resolveState();
      }
    });
    await _resolveState();
  }

  Future<void> _handleConfirmationLink() async {
    if (mounted) setState(() => _state = _GateState.verifyingEmailLink);
    final result = await _authService.handleEmailConfirmationLink();

    switch (result.outcome) {
      case EmailLinkOutcome.confirmed:
        final user = _authService.getCurrentUser();
        if (user != null) {
          await _pendingStore.markShowVerifiedSuccess(user.id);
        }
        _linkMessage = null;
        break;
      case EmailLinkOutcome.expired:
      case EmailLinkOutcome.failed:
        _linkMessage = result.message;
        break;
      case EmailLinkOutcome.none:
        break;
    }
  }

  Future<void> _resolveState() async {
    if (_isResolving || !mounted) return;
    _isResolving = true;

    try {
      if (!SupabaseConfig.isConfigured) {
        setState(() => _state = _GateState.configError);
        return;
      }

      final user = _authService.getCurrentUser();
      final session = _authService.getCurrentSession();

      // Источник истины — auth session, не profiles.
      if (user == null || session == null) {
        _pendingEmail = await _pendingStore.getPendingEmail();
        final pendingOnboarding = await _pendingStore.getPendingOnboarding();
        _incompleteOnboarding = pendingOnboarding ?? const OnboardingData();

        final awaitingEmail = _pendingEmail != null && _pendingEmail!.isNotEmpty;
        if (awaitingEmail || _linkMessage != null) {
          setState(() => _state = _GateState.awaitingEmailConfirmation);
        } else {
          setState(() => _state = _GateState.unauthenticated);
        }
        return;
      }

      UserProfile? profile;
      try {
        profile = await _profileService.ensureCurrentUserProfile();
      } on StateError {
        profile = await _profileService.getCurrentProfile();
        _incompleteOnboarding = _profileService.incompleteOnboardingData(
          profile: profile,
          pending: await _pendingStore.getPendingOnboarding(),
        );
        setState(() => _state = _GateState.incompleteProfile);
        return;
      }

      if (!profile.isComplete) {
        _incompleteOnboarding = _profileService.incompleteOnboardingData(
          profile: profile,
        );
        setState(() => _state = _GateState.incompleteProfile);
        return;
      }

      final hasShown =
          await _pendingStore.hasShownVerifiedSuccess(user.id);
      final shouldShow =
          await _pendingStore.shouldShowVerifiedSuccess(user.id);

      if (!hasShown && shouldShow && user.emailConfirmedAt != null) {
        setState(() => _state = _GateState.emailVerifiedSuccess);
        return;
      }

      setState(() => _state = _GateState.ready);
    } finally {
      _isResolving = false;
    }
  }

  Future<void> _onEmailVerifiedStart() async {
    final user = _authService.getCurrentUser();
    if (user != null) {
      await _pendingStore.markVerifiedSuccessShown(user.id);
    }
    await _resolveState();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _GateState.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      _GateState.verifyingEmailLink => const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Подтверждаем почту…'),
              ],
            ),
          ),
        ),
      _GateState.configError => const SupabaseConfigErrorScreen(),
      _GateState.unauthenticated => const WelcomeScreen(),
      _GateState.awaitingEmailConfirmation => EmailVerificationPendingScreen(
          email: _pendingEmail ?? '',
          onboardingData: _incompleteOnboarding,
          authService: _authService,
          onConfirmed: _resolveState,
          initialMessage: _linkMessage,
        ),
      _GateState.emailVerifiedSuccess => EmailVerifiedSuccessScreen(
          onStart: _onEmailVerifiedStart,
        ),
      _GateState.incompleteProfile => OnboardingNameScreen(
          onboardingData: _incompleteOnboarding,
        ),
      _GateState.ready => const MainShellScreen(),
    };
  }
}
