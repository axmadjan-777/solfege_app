import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../ai/screens/ai_assistant_placeholder_screen.dart';
import '../practice/screens/practice_placeholder_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../scales/screens/scales_list_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _index = 0;

  static const _tabs = [
    _ShellTab(
      label: 'Гаммы',
      icon: Icons.music_note_rounded,
      screen: ScalesListScreen(),
    ),
    _ShellTab(
      label: 'Практика',
      icon: Icons.fitness_center_rounded,
      screen: PracticePlaceholderScreen(),
    ),
    _ShellTab(
      label: 'ИИ',
      icon: Icons.auto_awesome_rounded,
      screen: AiAssistantPlaceholderScreen(),
    ),
    _ShellTab(
      label: 'Профиль',
      icon: Icons.person_rounded,
      screen: ProfileScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _tabs.map((tab) => tab.screen).toList(),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: NavigationBar(
            height: 68,
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.coral.withValues(alpha: 0.15),
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: _tabs
                .map(
                  (tab) => NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(
                      tab.icon,
                      color: AppColors.coral,
                    ),
                    label: tab.label,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({
    required this.label,
    required this.icon,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final Widget screen;
}
