import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coach_catalog.dart';

abstract class CoachPersistence {
  Future<bool> isDone();

  Future<void> markDone();
}

class MemoryCoachPersistence implements CoachPersistence {
  MemoryCoachPersistence({this.done = false});

  bool done;

  @override
  Future<bool> isDone() async => done;

  @override
  Future<void> markDone() async {
    done = true;
  }
}

class PreferencesCoachPersistence implements CoachPersistence {
  const PreferencesCoachPersistence();

  static const key = 'coach_route_v1';

  @override
  Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  @override
  Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }
}

class CoachController extends ChangeNotifier {
  CoachController({
    this.steps = coachSteps,
    CoachPersistence? persistence,
    bool done = false,
  })  : persistence = persistence ?? const PreferencesCoachPersistence(),
        _done = done;

  final List<CoachStep> steps;
  final CoachPersistence persistence;
  var index = 0;
  var armed = false;
  bool _done;
  VoidCallback? onPopRoute;
  ValueChanged<int>? onShowTab;

  bool get done => _done;

  bool get visible => armed && !_done && index < steps.length;

  CoachStep? get step => visible ? steps[index] : null;

  void arm() {
    if (_done || armed) return;
    armed = true;
    _applyTab();
    notifyListeners();
  }

  void note(String action) {
    if (step?.action != action) return;
    advance();
  }

  void advance() {
    if (!visible) return;
    final pop = step?.popOnAdvance ?? false;
    if (index + 1 >= steps.length) {
      finish();
      if (pop) onPopRoute?.call();
      return;
    }
    index += 1;
    if (pop) onPopRoute?.call();
    _applyTab();
    notifyListeners();
  }

  void skip() => finish();

  void finish({bool persist = true}) {
    if (_done) return;
    _done = true;
    armed = false;
    notifyListeners();
    if (persist) persistence.markDone();
  }

  void _applyTab() {
    final tab = step?.showTab;
    if (tab != null) onShowTab?.call(tab);
  }
}
