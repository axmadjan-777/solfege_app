import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/auth/models/musician_level.dart';
import 'package:solfege_app/features/auth/models/onboarding_data.dart';
import 'package:solfege_app/features/auth/screens/auth_screen.dart';

void main() {
  testWidgets('auth screen exposes only email registration and login', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(
          onboardingData: OnboardingData(
            displayName: 'Тест',
            age: 25,
            musicianLevel: MusicianLevel.beginner,
          ),
        ),
      ),
    );

    expect(find.text('Создать аккаунт'), findsOneWidget);
    expect(find.text('Уже есть аккаунт? Войти'), findsOneWidget);
    expect(find.text('Регистрация по телефону'), findsNothing);
    expect(find.text('Вход по телефону'), findsNothing);
  });
}
