import '../models/key_signature_category.dart';
import '../models/scale.dart';

class KeySignatureInfo {
  const KeySignatureInfo({
    required this.signCount,
    required this.category,
  });

  final int signCount;
  final KeySignatureCategory category;

  bool get isSharp => category == KeySignatureCategory.sharps;
  bool get isFlat => category == KeySignatureCategory.flats;
}

/// Знаки при ключе для гамм приложения (минор — как у относительного мажора).
abstract final class KeySignatureLookup {
  static const _groups = <String, KeySignatureInfo>{
    'c_a': KeySignatureInfo(signCount: 0, category: KeySignatureCategory.none),
    'g_e': KeySignatureInfo(signCount: 1, category: KeySignatureCategory.sharps),
    'd_b': KeySignatureInfo(signCount: 2, category: KeySignatureCategory.sharps),
    'a_fs': KeySignatureInfo(signCount: 3, category: KeySignatureCategory.sharps),
    'e_cs': KeySignatureInfo(signCount: 4, category: KeySignatureCategory.sharps),
    'b_gs': KeySignatureInfo(signCount: 5, category: KeySignatureCategory.sharps),
    'fs_ds': KeySignatureInfo(signCount: 6, category: KeySignatureCategory.sharps),
    'cs_as': KeySignatureInfo(signCount: 7, category: KeySignatureCategory.sharps),
    'f_d': KeySignatureInfo(signCount: 1, category: KeySignatureCategory.flats),
    'bb_g': KeySignatureInfo(signCount: 2, category: KeySignatureCategory.flats),
    'eb_c': KeySignatureInfo(signCount: 3, category: KeySignatureCategory.flats),
    'ab_f': KeySignatureInfo(signCount: 4, category: KeySignatureCategory.flats),
    'db_bf': KeySignatureInfo(signCount: 5, category: KeySignatureCategory.flats),
    'gb_ef': KeySignatureInfo(signCount: 6, category: KeySignatureCategory.flats),
    'cb_af': KeySignatureInfo(signCount: 7, category: KeySignatureCategory.flats),
  };

  static KeySignatureInfo forScale(Scale scale) {
    for (final entry in _groups.entries) {
      if (scale.id.startsWith('${entry.key}_')) {
        return entry.value;
      }
    }
    return const KeySignatureInfo(
      signCount: 0,
      category: KeySignatureCategory.none,
    );
  }
}
