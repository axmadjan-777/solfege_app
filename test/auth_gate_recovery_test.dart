import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/auth/models/onboarding_data.dart';
import 'package:solfege_app/features/auth/models/user_profile.dart';
import 'package:solfege_app/features/auth/screens/auth_gate.dart';
import 'package:solfege_app/features/auth/screens/onboarding_name_screen.dart';
import 'package:solfege_app/features/auth/screens/reset_password_screen.dart';
import 'package:solfege_app/features/auth/screens/welcome_screen.dart';
import 'package:solfege_app/features/auth/services/auth_service.dart';
import 'package:solfege_app/features/auth/services/pending_registration_store.dart';
import 'package:solfege_app/features/auth/services/profile_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _user = User(
  id: 'recovery-user',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-11-04T00:00:00Z',
);

final _session = Session(
  accessToken: 'test-access-token',
  tokenType: 'bearer',
  user: _user,
);

const _incompleteProfile = UserProfile(
  id: 'recovery-user',
  displayName: '',
  age: null,
  musicianLevel: null,
  onboardingCompleted: false,
);

class _Auth extends AuthService {
  final events = StreamController<AuthState>.broadcast();
  Session? session = _session;

  @override
  bool get isConfigured => true;

  @override
  Stream<AuthState> get authStateChanges => events.stream;

  @override
  Session? getCurrentSession() => session;

  @override
  User? getCurrentUser() => session?.user;

  @override
  bool isPasswordRecoveryLink([Uri? uri]) => false;

  @override
  bool isEmailConfirmationLink([Uri? uri]) => false;
}

class _Pending extends PendingRegistrationStore {
  final write = Completer<void>();
  String? recoveryUserId;

  @override
  Future<void> markPasswordRecoveryPending(String userId) async {
    await write.future;
    recoveryUserId = userId;
  }

  @override
  Future<void> clearPasswordRecoveryPending() async => recoveryUserId = null;

  @override
  Future<bool> isPasswordRecoveryPending(String userId) async =>
      recoveryUserId == userId;

  @override
  Future<String?> getPendingEmail() async => null;

  @override
  Future<OnboardingData?> getPendingOnboarding() async => null;
}

class _Profile extends ProfileService {
  final result = Completer<UserProfile>();
  var reads = 0;

  @override
  Future<UserProfile> ensureCurrentUserProfile({
    OnboardingData? onboardingData,
    String? authUserId,
  }) {
    reads += 1;
    return result.future;
  }

  @override
  OnboardingData incompleteOnboardingData({
    UserProfile? profile,
    OnboardingData? pending,
  }) =>
      const OnboardingData();
}

void main() {
  testWidgets(
    'recovery wins over an in-flight profile read and token events until done',
    (tester) async {
      final auth = _Auth();
      final pending = _Pending();
      final profile = _Profile();
      addTearDown(auth.events.close);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authService: auth,
            pendingStore: pending,
            profileService: profile,
          ),
        ),
      );
      await tester.pump();
      expect(profile.reads, 1);

      // The recovery event arrives while a previous profile read is pending,
      // and writing the persistent recovery marker is also delayed.
      auth.events.add(AuthState(AuthChangeEvent.passwordRecovery, _session));
      await tester.pump();
      profile.result.complete(_incompleteProfile);
      await tester.pump();
      await tester.pump();
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.byType(OnboardingNameScreen), findsNothing);

      for (final event in [
        AuthChangeEvent.signedIn,
        AuthChangeEvent.tokenRefreshed,
      ]) {
        auth.events.add(AuthState(event, _session));
        await tester.pump();
        expect(find.byType(ResetPasswordScreen), findsOneWidget);
      }
      expect(profile.reads, 1);

      pending.write.complete();
      await tester.pump();
      await tester
          .widget<ResetPasswordScreen>(find.byType(ResetPasswordScreen))
          .onPasswordUpdated();
      await tester.pump();
      expect(pending.recoveryUserId, isNull);
      expect(find.byType(OnboardingNameScreen), findsOneWidget);
      expect(find.byType(ResetPasswordScreen), findsNothing);
    },
  );

  testWidgets('sign-out releases the active recovery screen', (tester) async {
    final auth = _Auth();
    final pending = _Pending()..write.complete();
    final profile = _Profile()..result.complete(_incompleteProfile);
    addTearDown(auth.events.close);

    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authService: auth,
          pendingStore: pending,
          profileService: profile,
        ),
      ),
    );
    await tester.pumpAndSettle();
    auth.events.add(AuthState(AuthChangeEvent.passwordRecovery, _session));
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordScreen), findsOneWidget);

    auth.session = null;
    auth.events.add(const AuthState(AuthChangeEvent.signedOut, null));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(pending.recoveryUserId, isNull);
  });

  testWidgets('sign-out waits for the recovery marker and clears it',
      (tester) async {
    final auth = _Auth();
    final pending = _Pending();
    final profile = _Profile();
    addTearDown(auth.events.close);

    await tester.pumpWidget(MaterialApp(
      home: AuthGate(
        authService: auth,
        pendingStore: pending,
        profileService: profile,
      ),
    ));
    await tester.pump();
    auth.events.add(AuthState(AuthChangeEvent.passwordRecovery, _session));
    await tester.pump();
    auth.session = null;
    auth.events.add(const AuthState(AuthChangeEvent.signedOut, null));
    await tester.pump();
    profile.result.complete(_incompleteProfile);
    await tester.pump();

    pending.write.complete();
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(pending.recoveryUserId, isNull);
  });
}
