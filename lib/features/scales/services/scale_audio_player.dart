import '../models/scale.dart';
import '../models/scale_direction.dart';

/// Контракт воспроизведения гамм. UI зависит от абстракции, не от реализации.
abstract interface class ScaleAudioPlayer {
  Future<void> play(Scale scale, ScaleDirection direction);

  Future<void> stop();

  Future<void> dispose();
}
