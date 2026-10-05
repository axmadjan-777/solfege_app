import 'package:flutter/material.dart';

import '../logic/note_pitch.dart';
import '../logic/staff_geometry.dart';
import 'trainer_palette.dart';

class SheetMusicWidget extends StatefulWidget {
  const SheetMusicWidget({
    super.key,
    required this.notes,
    required this.positions,
    required this.activeIndex,
    required this.solvedCount,
    this.lineGap = 12,
  });

  final List<String> notes;
  final List<int> positions;
  final int activeIndex;
  final int solvedCount;
  final double lineGap;

  @override
  State<SheetMusicWidget> createState() => _SheetMusicWidgetState();
}

class _SheetMusicWidgetState extends State<SheetMusicWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lineColor = Theme.of(context).brightness == Brightness.dark
        ? TrainerPalette.line
        : Colors.black;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        return CustomPaint(
          painter: _StaffPainter(
            notes: widget.notes,
            positions: widget.positions,
            activeIndex: widget.activeIndex,
            solvedCount: widget.solvedCount,
            lineGap: widget.lineGap,
            lineColor: lineColor,
            pulse: _pulse.value,
          ),
          child: const SizedBox(height: 132, width: double.infinity),
        );
      },
    );
  }
}

class _StaffPainter extends CustomPainter {
  _StaffPainter({
    required this.notes,
    required this.positions,
    required this.activeIndex,
    required this.solvedCount,
    required this.lineGap,
    required this.lineColor,
    required this.pulse,
  });

  final List<String> notes;
  final List<int> positions;
  final int activeIndex;
  final int solvedCount;
  final double lineGap;
  final Color lineColor;
  final double pulse;

  static const _top = 36.0;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = _top + i * lineGap;
      canvas.drawLine(Offset(28, y), Offset(size.width - 8, y), linePaint);
    }
    final count = notes.length;
    if (count == 0) return;
    const start = 56.0;
    final step = count == 1 ? 0.0 : (size.width - start - 24) / (count - 1);
    for (var i = 0; i < count; i++) {
      final position = i < positions.length ? positions[i] : 0;
      final y = staffNoteY(position, top: _top, lineGap: lineGap);
      final x = start + step * i;
      _ledger(canvas, x, y, linePaint);
      final passed = i < solvedCount;
      final active = i == activeIndex && i >= solvedCount;
      final color = passed
          ? TrainerPalette.green
          : active
              ? TrainerPalette.blue
              : TrainerPalette.muted;
      final scale = active ? 1 + pulse * 0.18 : 1.0;
      final head = Rect.fromCenter(
        center: Offset(x, y),
        width: 16 * scale,
        height: 11 * scale,
      );
      canvas.drawOval(head, Paint()..color = color);
      canvas.drawLine(
        Offset(x + 7 * scale, y),
        Offset(x + 7 * scale, y - 28),
        Paint()
          ..color = color
          ..strokeWidth = 1.4,
      );
      _label(canvas, notes[i], x, size.height - 4);
    }
  }

  void _ledger(Canvas canvas, double x, double y, Paint paint) {
    const topLine = _top;
    final bottomLine = _top + 4 * lineGap;
    if (y < topLine - 2 || y > bottomLine + 2) {
      canvas.drawLine(Offset(x - 12, y), Offset(x + 12, y), paint);
    }
  }

  void _label(Canvas canvas, String note, double x, double baseline) {
    final painter = TextPainter(
      text: TextSpan(
        text: shortName(note),
        style: const TextStyle(color: TrainerPalette.muted, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x - painter.width / 2, baseline - painter.height));
  }

  @override
  bool shouldRepaint(covariant _StaffPainter oldDelegate) {
    return oldDelegate.pulse != pulse ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.solvedCount != solvedCount ||
        oldDelegate.notes != notes;
  }
}
