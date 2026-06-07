import '../models/key_signature_category.dart';
import '../models/key_signature_group.dart';
import '../models/scale.dart';
import 'scale_builder.dart';

class ScalesRepository {
  const ScalesRepository();

  static final List<KeySignatureGroup> _groups =
      const ScaleBuilder().buildAllGroups();

  List<KeySignatureGroup> getGroups({KeySignatureFilter filter = KeySignatureFilter.all}) {
    return switch (filter) {
      KeySignatureFilter.all => _groups,
      KeySignatureFilter.none =>
        _groups.where((g) => g.category == KeySignatureCategory.none).toList(),
      KeySignatureFilter.sharps =>
        _groups.where((g) => g.category == KeySignatureCategory.sharps).toList(),
      KeySignatureFilter.flats =>
        _groups.where((g) => g.category == KeySignatureCategory.flats).toList(),
    };
  }

  KeySignatureGroup? findGroupById(String id) {
    for (final group in _groups) {
      if (group.id == id) return group;
    }
    return null;
  }

  Scale? findScaleById(String id) {
    for (final group in _groups) {
      for (final scale in group.scales) {
        if (scale.id == id) return scale;
      }
    }
    return null;
  }
}
