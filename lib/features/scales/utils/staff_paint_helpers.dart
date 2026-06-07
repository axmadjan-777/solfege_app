import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/scale.dart';
import 'key_signature_lookup.dart';
import 'treble_staff_layout.dart';

class StaffPaintConfig {
  const StaffPaintConfig({
    this.topPadding = 28,
    this.lineGap = 10,
    this.clefWidth = 34,
    this.accidentalSpacing = 11,
  });

  final double topPadding;
  final double lineGap;
  final double clefWidth;
  final double accidentalSpacing;

  double get staffTop => topPadding;
  double get staffBottom => topPadding + 4 * lineGap;

  double leftInset(int keySignCount) =>
      8 + clefWidth + (keySignCount == 0 ? 6 : keySignCount * accidentalSpacing + 8);
}

abstract final class StaffPaintHelpers {
  static void drawStaffLines(
    Canvas canvas,
    Size size,
    StaffPaintConfig config,
    double leftInset,
  ) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = config.topPadding + i * config.lineGap;
      canvas.drawLine(Offset(leftInset, y), Offset(size.width - 8, y), paint);
    }
  }

  static void drawTrebleClef(Canvas canvas, StaffPaintConfig config) {
    final gLineY = TrebleStaffLayout.yForMidi(
      TrebleStaffLayout.referenceMidi,
      topPadding: config.topPadding,
      lineGap: config.lineGap,
    );
    final clef = TextPainter(
      text: const TextSpan(
        text: '𝄞',
        style: TextStyle(
          fontSize: 46,
          color: AppColors.textPrimary,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const x = 10.0;
    final y = gLineY - clef.height * 0.38;
    clef.paint(canvas, Offset(x, y));
  }

  static void drawKeySignature(
    Canvas canvas,
    Scale scale,
    StaffPaintConfig config,
  ) {
    final info = KeySignatureLookup.forScale(scale);
    if (info.signCount == 0) return;
    final symbol = TrebleStaffLayout.accidentalSymbol(info.category);
    final midis = TrebleStaffLayout.keySignatureMidis(scale);
    var x = 10 + config.clefWidth;
    for (final midi in midis) {
      final y = TrebleStaffLayout.yForMidi(
        midi,
        topPadding: config.topPadding,
        lineGap: config.lineGap,
      );
      _drawAccidental(canvas, Offset(x, y), symbol);
      x += config.accidentalSpacing;
    }
  }

  static void drawNoteHead(
    Canvas canvas,
    Offset center, {
    required bool filled,
    double width = 12,
    double height = 9,
  }) {
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    if (filled) {
      canvas.drawOval(
        rect,
        Paint()
          ..color = AppColors.textPrimary
          ..style = PaintingStyle.fill,
      );
    } else {
      canvas.drawOval(
        rect,
        Paint()
          ..color = AppColors.textPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  static void drawLedgerLines(
    Canvas canvas,
    double x,
    int midi,
    StaffPaintConfig config,
  ) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    final top = TrebleStaffLayout.topStaffLine(config.topPadding);
    final bottom = TrebleStaffLayout.bottomStaffLine(
      config.topPadding,
      config.lineGap,
    );
    final y = TrebleStaffLayout.yForMidi(
      midi,
      topPadding: config.topPadding,
      lineGap: config.lineGap,
    );
    final half = config.lineGap / 2;
    const ledgerWidth = 16.0;

    if (y < top - 0.5) {
      for (var ledgerY = top - half; ledgerY >= y - 0.5; ledgerY -= half) {
        canvas.drawLine(
          Offset(x - ledgerWidth / 2, ledgerY),
          Offset(x + ledgerWidth / 2, ledgerY),
          paint,
        );
      }
    } else if (y > bottom + 0.5) {
      for (var ledgerY = bottom + half; ledgerY <= y + 0.5; ledgerY += half) {
        canvas.drawLine(
          Offset(x - ledgerWidth / 2, ledgerY),
          Offset(x + ledgerWidth / 2, ledgerY),
          paint,
        );
      }
    }
  }

  static void drawResolutionArc(
    Canvas canvas,
    Offset from,
    Offset to,
  ) {
    final paint = Paint()
      ..color = AppColors.coral.withValues(alpha: 0.85)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    final midX = (from.dx + to.dx) / 2;
    final lift = math.min(18.0, (to.dx - from.dx).abs() * 0.35 + 10);
    final control = Offset(midX, math.min(from.dy, to.dy) - lift);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
    canvas.drawPath(path, paint);

    const arrowSize = 4.0;
    final angle = math.atan2(to.dy - control.dy, to.dx - control.dx);
    final head = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - arrowSize * math.cos(angle - math.pi / 6),
        to.dy - arrowSize * math.sin(angle - math.pi / 6),
      )
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - arrowSize * math.cos(angle + math.pi / 6),
        to.dy - arrowSize * math.sin(angle + math.pi / 6),
      );
    canvas.drawPath(head, paint);
  }

  static void drawDegreeLabel(
    Canvas canvas,
    Offset center,
    String label,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - 18));
  }

  static void _drawAccidental(Canvas canvas, Offset center, String symbol) {
    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx, center.dy - tp.height / 2));
  }
}
