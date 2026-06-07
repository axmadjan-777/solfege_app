import 'scale_direction.dart';
import 'scale_mode.dart';

class Scale {
  const Scale({
    required this.id,
    required this.name,
    required this.tonic,
    required this.mode,
    required this.notes,
    required this.midiNotes,
    required this.description,
    required this.listeningTips,
    this.descendingNotes,
    this.descendingMidiNotes,
  });

  final String id;
  final String name;
  final String tonic;
  final ScaleMode mode;
  final List<String> notes;
  final List<int> midiNotes;
  final String description;
  final List<String> listeningTips;

  /// Отличается от [notes.reversed] у мелодического минора (ход вниз — натуральные VI и VII).
  final List<String>? descendingNotes;
  final List<int>? descendingMidiNotes;

  static const degrees = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];

  /// Ноты в порядке проигрывания — использовать в audio player.
  List<String> noteSequence(ScaleDirection direction) {
    return switch (direction) {
      ScaleDirection.ascending => _ascendingNotes(),
      ScaleDirection.descending => _descendingNotes(),
      ScaleDirection.upDown => _combineSequences(
          _ascendingNotes(),
          _descendingNotes(),
        ),
    };
  }

  /// MIDI-номера в порядке проигрывания — использовать в audio player.
  List<int> midiSequence(ScaleDirection direction) {
    return switch (direction) {
      ScaleDirection.ascending => _ascendingMidi(),
      ScaleDirection.descending => _descendingMidi(),
      ScaleDirection.upDown => _combineSequences(
          _ascendingMidi(),
          _descendingMidi(),
        ),
    };
  }

  List<String> _ascendingNotes() => [...notes, notes.first];

  List<int> _ascendingMidi() => [...midiNotes, midiNotes.first + 12];

  List<String> _descendingNotes() {
    final highTonic = notes.first;
    final body = descendingNotes ?? notes.reversed.toList();
    if (body.isNotEmpty && body.first == notes.first) {
      return [highTonic, ...body.skip(1)];
    }
    return [highTonic, ...body];
  }

  List<int> _descendingMidi() {
    final highTonic = midiNotes.first + 12;
    final body = descendingMidiNotes ?? midiNotes.reversed.toList();
    if (body.isNotEmpty && body.first == midiNotes.first) {
      return [highTonic, ...body.skip(1)];
    }
    return [highTonic, ...body];
  }

  List<T> _combineSequences<T>(List<T> ascending, List<T> descending) {
    if (ascending.isEmpty) return descending;
    if (descending.isEmpty) return ascending;
    if (descending.first == ascending.last) {
      return [...ascending, ...descending.skip(1)];
    }
    return [...ascending, ...descending];
  }
}
