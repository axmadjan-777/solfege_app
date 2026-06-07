import 'key_signature_category.dart';
import 'scale.dart';

class KeySignatureGroup {
  const KeySignatureGroup({
    required this.id,
    required this.title,
    required this.category,
    required this.signCount,
    required this.signLabels,
    required this.scales,
  });

  final String id;
  final String title;
  final KeySignatureCategory category;
  final int signCount;
  final List<String> signLabels;
  final List<Scale> scales;

  String get signCountLabel {
    if (signCount == 0) return 'нет';
    final word = category == KeySignatureCategory.sharps ? 'диез' : 'бемоль';
    final suffix = switch (signCount) {
      1 => '',
      2 || 3 || 4 => 'а',
      _ => 'ов',
    };
    return '$signCount $word$suffix';
  }

  List<Scale> get majorScales =>
      scales.where((scale) => scale.mode.isMajor).toList();

  List<Scale> get minorScales =>
      scales.where((scale) => scale.mode.isMinor).toList();
}
