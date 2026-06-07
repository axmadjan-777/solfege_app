import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/screens/auth_gate.dart';

class SolfegeApp extends StatelessWidget {
  const SolfegeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Сольфеджио',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}
