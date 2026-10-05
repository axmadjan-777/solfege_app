import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../ai/screens/ai_chat_screen.dart';
import '../practice/progress/practice_progress_binding.dart';
import '../practice/screens/practice_map_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../scales/screens/scales_list_screen.dart';
import '../theory/screens/theory_home_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _index = 0;
  late final Future<PracticeProgressBinding> _progress = loadPracticeProgress();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PracticeProgressBinding>(
      future: _progress,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
              body: Center(child: Text('Не удалось загрузить прогресс')));
        }
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final binding = snapshot.data!;
        final tabs = [
          const _ShellTab(
              label: 'Гаммы',
              icon: Icons.music_note_rounded,
              screen: ScalesListScreen()),
          _ShellTab(
            label: 'Теория',
            icon: Icons.menu_book_rounded,
            screen: TheoryHomeScreen(
                catalog: binding.catalog,
                progress: binding.progress,
                clock: binding.clock),
          ),
          _ShellTab(
            label: 'Практика',
            icon: Icons.fitness_center_rounded,
            screen: PracticeMapScreen(
                catalog: binding.catalog,
                progress: binding.progress,
                clock: binding.clock),
          ),
          const _ShellTab(
              label: 'ИИ',
              icon: Icons.auto_awesome_rounded,
              screen: AiChatScreen()),
          const _ShellTab(
              label: 'Профиль',
              icon: Icons.person_rounded,
              screen: ProfileScreen()),
        ];
        return _Shell(
            index: _index,
            tabs: tabs,
            onSelected: (value) => setState(() => _index = value));
      },
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell(
      {required this.index, required this.tabs, required this.onSelected});

  final int index;
  final List<_ShellTab> tabs;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: tabs.map((tab) => tab.screen).toList(),
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
            selectedIndex: index,
            onDestinationSelected: onSelected,
            destinations: tabs
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
