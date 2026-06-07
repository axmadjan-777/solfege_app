import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../../core/theme/app_colors.dart';

class SupabaseConfigErrorScreen extends StatelessWidget {
  const SupabaseConfigErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Icon(
                Icons.settings_outlined,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Supabase не настроен',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              Text(
                SupabaseConfig.diagnosticMessage,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                SupabaseConfig.configurationHint,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
