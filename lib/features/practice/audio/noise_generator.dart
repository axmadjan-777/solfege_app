import 'dart:math';
import 'dart:typed_data';

import 'audio_sequence.dart';

/// Seeded, mono 16-bit PCM white noise. No recordings or external assets.
abstract final class NoiseGenerator {
  static const sampleRate = 44100;

  static Uint8List wav({
    required int seed,
    int durationMs = 700,
    double volume = practiceAudioVolume,
  }) {
    if (durationMs <= 0 || !volume.isFinite || volume < 0 || volume > 1) {
      throw ArgumentError(
          'Expected positive duration and volume between 0 and 1');
    }
    final count = (sampleRate * durationMs / 1000).round();
    final signal = Float64List(count);
    final envelope = Float64List(count);
    var state = seed & 0xffffffff;
    if (state == 0) state = 0x6d2b79f5;
    var weightedSum = 0.0;
    var weight = 0.0;
    final ramp = min(sampleRate * 0.025, (count - 1) / 2);
    for (var i = 0; i < count; i++) {
      // Explicit 32-bit PRNG gives the same PCM on VM and web.
      state = (state ^ ((state << 13) & 0xffffffff)) & 0xffffffff;
      state = (state ^ (state >>> 17)) & 0xffffffff;
      state = (state ^ ((state << 5) & 0xffffffff)) & 0xffffffff;
      signal[i] = state / 0xffffffff * 2 - 1;
      final edge = min(i, count - 1 - i) / ramp;
      envelope[i] = edge >= 1 ? 1 : (1 - cos(pi * edge)) / 2;
      weightedSum += signal[i] * envelope[i];
      weight += envelope[i];
    }
    final mean = weightedSum / weight;
    var peak = 0.0;
    for (var i = 0; i < count; i++) {
      signal[i] = (signal[i] - mean) * envelope[i];
      peak = max(peak, signal[i].abs());
    }
    final bytes = ByteData(44 + count * 2);
    void tag(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    tag(0, 'RIFF');
    bytes.setUint32(4, bytes.lengthInBytes - 8, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    tag(36, 'data');
    bytes.setUint32(40, count * 2, Endian.little);
    final gain = peak == 0 ? 0.0 : volume * 32767 / peak;
    for (var i = 0; i < count; i++) {
      bytes.setInt16(44 + i * 2, (signal[i] * gain).round(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
