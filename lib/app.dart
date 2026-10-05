import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/screens/auth_gate.dart';
import 'features/coach/coach_controller.dart';
import 'features/coach/coach_layer.dart';

class SolfegeApp extends StatefulWidget {
  const SolfegeApp({super.key, this.coach});

  final CoachController? coach;

  @override
  State<SolfegeApp> createState() => _SolfegeAppState();
}

class _SolfegeAppState extends State<SolfegeApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final CoachController _coach = widget.coach ?? CoachController();

  @override
  void dispose() {
    if (widget.coach == null) _coach.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CoachScope(
      controller: _coach,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Сольфеджио',
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          return CoachOverlay(
            navigatorKey: _navigatorKey,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const AuthGate(),
      ),
    );
  }
}
