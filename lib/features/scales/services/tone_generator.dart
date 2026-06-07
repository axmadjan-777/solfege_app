import 'dart:math';
import 'dart:typed_data';

/// Generates short sine-wave WAV bytes for a MIDI note (no external assets).
abstract final class ToneGenerator {
  static const _sampleRate = 44100;
  static const _bitsPerSample = 16;

  static Uint8List wavFromMidi(
    int midi, {
    int durationMs = 420,
    double volume = 0.35,
  }) {
    final frequency = 440 * pow(2, (midi - 69) / 12);
    return _generateWav(frequency.toDouble(), durationMs, volume);
  }

  static Uint8List _generateWav(
    double frequency,
    int durationMs,
    double volume,
  ) {
    final sampleCount = (_sampleRate * durationMs / 1000).round();
    final dataSize = sampleCount * 2;
    final bytes = BytesBuilder();
    final header = ByteData(44);

    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6d); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // space
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, _sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, _bitsPerSample, Endian.little);
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);
    bytes.add(header.buffer.asUint8List());

    final pcm = ByteData(dataSize);
    for (var i = 0; i < sampleCount; i++) {
      final t = i / _sampleRate;
      final envelope = min(1.0, i / 800) * max(0.0, 1 - (i / sampleCount));
      final sample = sin(2 * pi * frequency * t) * volume * envelope;
      final intSample = (sample * 32767).round().clamp(-32768, 32767);
      pcm.setInt16(i * 2, intSample, Endian.little);
    }
    bytes.add(pcm.buffer.asUint8List());
    return bytes.takeBytes();
  }
}
