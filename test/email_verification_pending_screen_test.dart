import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/auth/services/auth_service.dart';
import 'package:solfege_app/features/auth/screens/email_verification_pending_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService();

  final _controller = StreamController<AuthState>.broadcast();
  Session? session;
  int resendCount = 0;
  String? lastResendEmail;

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  Session? getCurrentSession() => session;

  @override
  Future<void> resendConfirmationEmail(String email) async {
    resendCount += 1;
    lastResendEmail = email;
  }
}

void main() {
  testWidgets('shows resend button and email hint', (tester) async {
    final auth = _FakeAuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationPendingScreen(
          email: 'user@example.com',
          authService: auth,
        ),
      ),
    );

    expect(find.text('E-Mail bestätigen'), findsOneWidget);
    expect(find.textContaining('user@example.com'), findsOneWidget);
    expect(find.text('E-Mail erneut senden'), findsOneWidget);
  });

  testWidgets('resend triggers email and starts a countdown cooldown',
      (tester) async {
    final auth = _FakeAuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationPendingScreen(
          email: 'user@example.com',
          authService: auth,
        ),
      ),
    );

    await tester.tap(find.text('E-Mail erneut senden'));
    await tester.pump();
    await tester.pump();

    expect(auth.resendCount, 1);
    expect(auth.lastResendEmail, 'user@example.com');
    // После отправки кнопка показывает отсчёт и заблокирована.
    expect(find.textContaining('E-Mail erneut senden ('), findsOneWidget);

    // Досчитываем таймер до конца, чтобы тест не оставил активный Timer.
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('confirm button without a session shows guidance, not a crash',
      (tester) async {
    final auth = _FakeAuthService()..session = null;
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationPendingScreen(
          email: 'user@example.com',
          authService: auth,
        ),
      ),
    );

    await tester.tap(find.text('Ich habe die E-Mail bestätigt'));
    await tester.pump();

    expect(
      find.textContaining('melde dich in der App erneut an'),
      findsOneWidget,
    );
  });
}
