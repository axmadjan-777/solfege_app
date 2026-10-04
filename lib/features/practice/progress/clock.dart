/// Часы снаружи, чтобы отложенная проверка не зависела от настоящего времени.
abstract interface class Clock {
  DateTime now();
}

class FixedClock implements Clock {
  FixedClock(this.current);

  DateTime current;

  void advance(Duration duration) {
    current = current.add(duration);
  }

  @override
  DateTime now() => current;
}
