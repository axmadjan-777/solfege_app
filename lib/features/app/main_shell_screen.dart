import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../ai/screens/ai_chat_screen.dart';
import '../coach/coach_catalog.dart';
import '../coach/coach_controller.dart';
import '../coach/coach_layer.dart';
import '../practice/progress/attempt.dart';
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
  var _coachBound = false;
  var _tourRunning = false;
  CoachController? _coach;
  late final Future<PracticeProgressBinding> _progress = loadPracticeProgress();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_coachBound) return;
    _coachBound = true;
    final coach = CoachScope.maybeOf(context);
    if (coach == null) return;
    _coach = coach;
    coach.onShowTab = (tab) {
      if (mounted) setState(() => _index = tab);
    };
    coach.addListener(_onCoach);
    _loadCoach(coach);
  }

  Future<void> _loadCoach(CoachController coach) async {
    try {
      if (await coach.persistence.isDone()) {
        if (mounted) coach.finish(persist: false);
        return;
      }
    } catch (_) {
      return;
    }
    if (mounted) coach.arm();
  }

  void _onCoach() {
    final coach = _coach;
    if (coach == null) return;
    if (coach.visible) _tourRunning = true;
    if (_tourRunning && coach.done && mounted) {
      _tourRunning = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Маршрут пройден. Сначала теория, затем практика.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _coach?.removeListener(_onCoach);
    if (_coach?.onShowTab != null) _coach?.onShowTab = null;
    super.dispose();
  }

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
            coachId: 'nav-theory',
            screen: TheoryHomeScreen(
              catalog: binding.catalog,
              progress: binding.progress,
              clock: binding.clock,
              needsReview: (id) =>
                  binding.progress.snapshot(id).status ==
                  CompetencyStatus.needsReview,
            ),
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
            coachId: 'nav-profile',
            screen: ProfileScreen(),
          ),
        ];
        return _Shell(
          index: _index,
          tabs: tabs,
          onSelected: (value) {
            setState(() => _index = value);
            final action = coachActionForTab(value);
            if (action != null) CoachScope.maybeOf(context)?.note(action);
          },
        );
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
                    icon: _navIcon(tab, selected: false),
                    selectedIcon: _navIcon(tab, selected: true),
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
    this.coachId,
  });

  final String label;
  final IconData icon;
  final Widget screen;
  final String? coachId;
}

Widget _navIcon(_ShellTab tab, {required bool selected}) {
  final icon = Icon(tab.icon, color: selected ? AppColors.coral : null);
  final id = tab.coachId;
  if (id == null) return icon;
  return CoachTarget(
    id: id,
    child: Padding(padding: const EdgeInsets.all(8), child: icon),
  );
}
