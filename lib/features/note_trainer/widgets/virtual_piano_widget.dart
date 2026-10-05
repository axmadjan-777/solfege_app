import 'package:flutter/material.dart';

import '../logic/note_pitch.dart';
import 'trainer_palette.dart';

class PianoKey {
  const PianoKey({
    required this.note,
    required this.whiteIndex,
    required this.black,
  });

  final String note;
  final int whiteIndex;
  final bool black;
}

/// Полторы октавы: белые C4–G5, чёрные на стыках C-D, D-E, F-G, G-A, A-B.
List<PianoKey> trainerPianoKeys() {
  const letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  const blackAfter = {'C': '#', 'D': 'b', 'F': '#', 'G': '#', 'A': 'b'};
  final whites = <PianoKey>[];
  final blacks = <PianoKey>[];
  for (var octave = 4; octave <= 5; octave++) {
    for (final letter in letters) {
      final note = '$letter$octave';
      final midi = midiOf(note);
      if (midi == null || midi > midiOf('G5')!) break;
      whites.add(PianoKey(note: note, whiteIndex: whites.length, black: false));
      final accidental = blackAfter[letter];
      if (accidental == null) continue;
      final blackNote = accidental == '#'
          ? '$letter#$octave'
          : _flatName(letter, octave);
      final blackMidi = midiOf(blackNote);
      if (blackMidi != null && blackMidi <= midiOf('G5')!) {
        blacks.add(PianoKey(
          note: blackNote,
          whiteIndex: whites.length - 1,
          black: true,
        ));
      }
    }
  }
  return [...whites, ...blacks];
}

String _flatName(String letter, int octave) {
  const next = {'C': 'D', 'D': 'E', 'F': 'G', 'G': 'A', 'A': 'B'};
  return '${next[letter]}b$octave';
}

class VirtualPianoWidget extends StatelessWidget {
  const VirtualPianoWidget({
    super.key,
    required this.showLabels,
    required this.onTap,
    this.activeNote,
  });

  final bool showLabels;
  final ValueChanged<String> onTap;
  final String? activeNote;

  @override
  Widget build(BuildContext context) {
    final keys = trainerPianoKeys();
    final whites = [for (final key in keys) if (!key.black) key];
    final blacks = [for (final key in keys) if (key.black) key];
    return LayoutBuilder(
      builder: (context, constraints) {
        final whiteWidth = constraints.maxWidth / whites.length;
        final blackWidth = whiteWidth * 0.62;
        return SizedBox(
          height: 168,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final key in whites)
                    Expanded(child: _KeyFace(
                      pianoKey: key,
                      showLabels: showLabels,
                      active: samePitch(key.note, activeNote ?? ''),
                      onTap: () => onTap(key.note),
                    )),
                ],
              ),
              for (final key in blacks)
                Positioned(
                  left: (key.whiteIndex + 1) * whiteWidth - blackWidth / 2,
                  top: 0,
                  width: blackWidth,
                  height: 104,
                  child: _KeyFace(
                    pianoKey: key,
                    showLabels: showLabels,
                    active: samePitch(key.note, activeNote ?? ''),
                    onTap: () => onTap(key.note),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _KeyFace extends StatelessWidget {
  const _KeyFace({
    required this.pianoKey,
    required this.showLabels,
    required this.active,
    required this.onTap,
  });

  final PianoKey pianoKey;
  final bool showLabels;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final black = pianoKey.black;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: black ? TrainerPalette.blackKey : TrainerPalette.whiteKey,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
        child: InkWell(
          key: Key('piano-key-${pianoKey.note}'),
          onTap: onTap,
          child: Stack(
            children: [
              if (active)
                const Align(
                  alignment: Alignment(0, -0.82),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: TrainerPalette.blue,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 10, height: 10),
                  ),
                ),
              if (showLabels)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      keyCaption(pianoKey.note),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: black ? Colors.white : Colors.black87,
                        fontSize: 9,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
