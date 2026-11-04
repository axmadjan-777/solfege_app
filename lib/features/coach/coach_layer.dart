import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'coach_catalog.dart';
import 'coach_controller.dart';

class CoachScope extends InheritedNotifier<CoachController> {
  const CoachScope({
    super.key,
    required CoachController controller,
    required super.child,
  }) : super(notifier: controller);

  static CoachController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CoachScope>()?.notifier;
  }
}

class CoachTarget extends StatefulWidget {
  const CoachTarget({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<CoachTarget> createState() => _CoachTargetState();
}

class _CoachTargetState extends State<CoachTarget> {
  final _key = GlobalKey();
  CoachController? _coach;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = CoachScope.maybeOf(context);
    if (!identical(next, _coach)) {
      _coach?.unregister(widget.id, _key);
      _coach = next;
    }
    _coach?.register(widget.id, _key);
  }

  @override
  void dispose() {
    _coach?.unregister(widget.id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

extension CoachTargets on CoachController {
  static final _keys = Expando<Map<String, GlobalKey>>();

  Map<String, GlobalKey> get _registry =>
      _keys[this] ??= <String, GlobalKey>{};

  void register(String id, GlobalKey key) {
    _registry[id] = key;
  }

  void unregister(String id, GlobalKey key) {
    if (_registry[id] == key) _registry.remove(id);
  }

  Rect? targetRect(String? id) {
    if (id == null) return null;
    final context = _registry[id]?.currentContext;
    final box = context?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// Затемнение с отверстием вокруг текущей цели. Нажатие проходит в саму кнопку.
class CoachOverlay extends StatefulWidget {
  const CoachOverlay({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<CoachOverlay> {
  CoachController? _coach;
  Rect? _hole;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = CoachScope.maybeOf(context);
    if (!identical(next, _coach)) {
      _coach?.removeListener(_sync);
      _coach = next;
      _coach?.addListener(_sync);
      _coach?.onPopRoute = _pop;
    }
  }

  @override
  void dispose() {
    if (_coach?.onPopRoute == _pop) _coach?.onPopRoute = null;
    _coach?.removeListener(_sync);
    super.dispose();
  }

  void _pop() {
    final navigator = widget.navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) navigator.pop();
  }

  void _sync() {
    if (!mounted) return;
    setState(() {});
    _measureSoon();
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _measureSoon();
    });
  }

  void _measureSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = _readHole();
      if (next == _hole) return;
      setState(() => _hole = next);
    });
  }

  Rect? _readHole() {
    final coach = _coach;
    final global = coach?.targetRect(coach.step?.targetId);
    if (global == null) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return global;
    return box.globalToLocal(global.topLeft) & global.size;
  }

  @override
  Widget build(BuildContext context) {
    final coach = _coach;
    final step = coach?.step;
    return Stack(
      children: [
        widget.child,
        if (coach != null && step != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                final hole = _hole?.inflate(10).intersect(Offset.zero & size);
                return Stack(
                  children: [
                    if (hole != null) ..._dim(size, hole),
                    if (hole != null)
                      Positioned.fromRect(
                        rect: hole,
                        child: const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.fromBorderSide(
                                BorderSide(color: AppColors.coral, width: 3),
                              ),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(16)),
                            ),
                          ),
                        ),
                      ),
                    _card(size, hole, step, coach),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  List<Widget> _dim(Size size, Rect hole) {
    final bars = [
      Rect.fromLTWH(0, 0, size.width, hole.top),
      Rect.fromLTWH(0, hole.top, hole.left, hole.height),
      Rect.fromLTWH(hole.right, hole.top, size.width - hole.right, hole.height),
      Rect.fromLTWH(0, hole.bottom, size.width, size.height - hole.bottom),
    ];
    return [
      for (final rect in bars)
        if (rect.width > 0 && rect.height > 0)
          Positioned.fromRect(
            rect: rect,
            child: GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Color(0x8C0B0B0B)),
            ),
          ),
    ];
  }

  Widget _card(Size size, Rect? hole, CoachStep step, CoachController coach) {
    final atBottom = hole == null || hole.center.dy < size.height * 0.5;
    final index = coach.index + 1;
    return Positioned(
      left: 16,
      right: 16,
      top: atBottom ? null : 24,
      bottom: atBottom ? 24 : null,
      child: Material(
        key: const Key('coach-card'),
        color: AppColors.surface,
        elevation: 8,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Шаг $index из ${coach.steps.length}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(step.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(step.body),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: coach.skip,
                    child: const Text('Пропустить'),
                  ),
                  const Spacer(),
                  if (!step.waitsForAction)
                    FilledButton(
                      key: const Key('coach-next'),
                      onPressed: coach.advance,
                      child: Text(step.primary),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
