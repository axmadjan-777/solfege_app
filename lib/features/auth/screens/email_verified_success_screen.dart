import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../widgets/primary_auth_button.dart';

class EmailVerifiedSuccessScreen extends StatelessWidget {
  const EmailVerifiedSuccessScreen({
    super.key,
    required this.onStart,
  });

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Icon(
                Icons.verified_outlined,
                size: 56,
                color: AppColors.success,
              ),
              const SizedBox(height: 24),
              Text(
                'Email подтверждён',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Аккаунт готов. Можно начинать заниматься сольфеджио.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const Spacer(),
              PrimaryAuthButton(
                label: 'Старт',
                onPressed: onStart,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
