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
    if (signCount == 0) return 'keine';
    if (category == KeySignatureCategory.sharps) {
      return signCount == 1 ? '1 Kreuz' : '$signCount Kreuze';
    }
    return signCount == 1 ? '1 Be' : '$signCount Bes';
  }

  List<Scale> get majorScales =>
      scales.where((scale) => scale.mode.isMajor).toList();

  List<Scale> get minorScales =>
      scales.where((scale) => scale.mode.isMinor).toList();
}
