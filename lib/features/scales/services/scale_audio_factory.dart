import 'scale_audio_player.dart';
import 'scale_audio_service.dart';
import 'scale_tone_audio_service.dart';

abstract final class ScaleAudioFactory {
  static ScaleAudioPlayer createDefault() => ScaleToneAudioService();

  static ScaleAudioPlayer createStub() => const ScaleAudioService();
}
