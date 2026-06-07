import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/scale.dart';
import '../utils/key_signature_lookup.dart';
import '../utils/scale_harmony.dart';
import '../utils/staff_paint_helpers.dart';
import '../utils/treble_staff_layout.dart';

class ScaleStaffCard extends StatelessWidget {
  const ScaleStaffCard({super.key, required this.scale});

  final Scale scale;

  @override
  Widget build(BuildContext context) {
    final resolutions = ScaleHarmony.resolutionsFor(scale);
    final displayMidi = [...scale.midiNotes, scale.midiNotes.first + 12];
    final displayDegrees = [...Scale.degrees, 'I'];

    const config = StaffPaintConfig();
    final keyCount = KeySignatureLookup.forScale(scale).signCount;
    final staffHeight = TrebleStaffLayout.minStaffHeight(
      midiNotes: displayMidi,
      topPadding: config.topPadding,
      lineGap: config.lineGap,
    ) + 28;

    final triadBlocks = [
      _TriadBlockData(
        title: 'Тоника (I)',
        rootIndex: ScaleHarmony.tonicIndex(scale),
      ),
      _TriadBlockData(
        title: 'Субдоминанта (IV)',
        rootIndex: ScaleHarmony.subdominantIndex(scale),
      ),
      _TriadBlockData(
        title: 'Доминанта (V)',
        rootIndex: ScaleHarmony.dominantIndex(scale),
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Нотный стан',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Устойчивые — контур, неустойчивые — заливка. Дуги — разрешения.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: staffHeight,
              width: double.infinity,
              child: CustomPaint(
                painter: _ScaleWithResolutionsPainter(
                  scale: scale,
                  midiNotes: displayMidi,
                  degrees: displayDegrees,
                  resolutions: resolutions,
                  config: config,
                  keySignCount: keyCount,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Трезвучия и обращения',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...triadBlocks.map(
              (block) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _TriadStaffSection(
                  scale: scale,
                  title: block.title,
                  rootIndex: block.rootIndex,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriadBlockData {
  const _TriadBlockData({
    required this.title,
    required this.rootIndex,
  });

  final String title;
  final int rootIndex;
}

class _TriadStaffSection extends StatelessWidget {
  const _TriadStaffSection({
    required this.scale,
    required this.title,
    required this.rootIndex,
  });

  final Scale scale;
  final String title;
  final int rootIndex;

  @override
  Widget build(BuildContext context) {
    final inversions = ScaleHarmony.triadInversions(scale, rootIndex);
    const config = StaffPaintConfig(topPadding: 20, lineGap: 8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        ...inversions.map((inv) {
          final midis = _midisForInversion(scale, rootIndex, inv.notes);
          final height = TrebleStaffLayout.minStaffHeight(
            midiNotes: midis,
            topPadding: config.topPadding,
            lineGap: config.lineGap,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: height,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _TriadStaffPainter(
                      scale: scale,
                      midiNotes: midis,
                      labels: inv.notes,
                      config: config,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  List<int> _midisForInversion(
    Scale scale,
    int rootIndex,
    List<String> orderedNotes,
  ) {
    final baseMidis = ScaleHarmony.triadMidis(scale, rootIndex);
    final baseNotes = ScaleHarmony.triadNotes(scale, rootIndex);
    return orderedNotes
        .map((note) => baseMidis[baseNotes.indexOf(note)])
        .toList();
  }
}

class _ScaleWithResolutionsPainter extends CustomPainter {
  _ScaleWithResolutionsPainter({
    required this.scale,
    required this.midiNotes,
    required this.degrees,
    required this.resolutions,
    required this.config,
    required this.keySignCount,
  });

  final Scale scale;
  final List<int> midiNotes;
  final List<String> degrees;
  final List<ScaleResolution> resolutions;
  final StaffPaintConfig config;
  final int keySignCount;

  static const _stableIndices = {0, 2, 4, 7};

  @override
  void paint(Canvas canvas, Size size) {
    final leftInset = config.leftInset(keySignCount);
    StaffPaintHelpers.drawStaffLines(canvas, size, config, leftInset);
    StaffPaintHelpers.drawTrebleClef(canvas, config);
    StaffPaintHelpers.drawKeySignature(canvas, scale, config);

    final noteAreaWidth = size.width - leftInset - 16;
    final spacing = noteAreaWidth / midiNotes.length;
    final centers = <Offset>[];

    for (var i = 0; i < midiNotes.length; i++) {
      final midi = midiNotes[i];
      final x = leftInset + spacing * i + spacing / 2;
      final y = TrebleStaffLayout.yForMidi(
        midi,
        topPadding: config.topPadding,
        lineGap: config.lineGap,
      );
      centers.add(Offset(x, y));

      StaffPaintHelpers.drawLedgerLines(canvas, x, midi, config);
      StaffPaintHelpers.drawNoteHead(
        canvas,
        Offset(x, y),
        filled: !_stableIndices.contains(i),
      );
      StaffPaintHelpers.drawDegreeLabel(canvas, Offset(x, y), degrees[i]);
    }

    for (final resolution in resolutions) {
      final fromIndex = Scale.degrees.indexOf(resolution.fromDegree);
      var toIndex = Scale.degrees.indexOf(resolution.toDegree);
      if (resolution.fromDegree == 'VII' && midiNotes.length > 7) {
        toIndex = 7;
      }
      if (fromIndex < 0 || toIndex < 0) continue;
      StaffPaintHelpers.drawResolutionArc(
        canvas,
        centers[fromIndex],
        centers[toIndex],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScaleWithResolutionsPainter oldDelegate) {
    return oldDelegate.scale.id != scale.id;
  }
}

class _TriadStaffPainter extends CustomPainter {
  _TriadStaffPainter({
    required this.scale,
    required this.midiNotes,
    required this.labels,
    required this.config,
  });

  final Scale scale;
  final List<int> midiNotes;
  final List<String> labels;
  final StaffPaintConfig config;

  @override
  void paint(Canvas canvas, Size size) {
    final keyCount = KeySignatureLookup.forScale(scale).signCount;
    final leftInset = config.leftInset(keyCount);
    StaffPaintHelpers.drawStaffLines(canvas, size, config, leftInset);
    StaffPaintHelpers.drawTrebleClef(canvas, config);
    StaffPaintHelpers.drawKeySignature(canvas, scale, config);

    final noteAreaWidth = size.width - leftInset - 16;
    final spacing = noteAreaWidth / midiNotes.length;

    for (var i = 0; i < midiNotes.length; i++) {
      final midi = midiNotes[i];
      final x = leftInset + spacing * i + spacing / 2;
      final y = TrebleStaffLayout.yForMidi(
        midi,
        topPadding: config.topPadding,
        lineGap: config.lineGap,
      );
      StaffPaintHelpers.drawLedgerLines(canvas, x, midi, config);
      StaffPaintHelpers.drawNoteHead(canvas, Offset(x, y), filled: false);

      final label = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(fontSize: 8, color: AppColors.textMuted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(x - label.width / 2, y + 7));
    }
  }

  @override
  bool shouldRepaint(covariant _TriadStaffPainter oldDelegate) {
    return oldDelegate.midiNotes != midiNotes;
  }
}
