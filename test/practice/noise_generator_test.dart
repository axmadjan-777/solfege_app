import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/practice/audio/audio_sequence.dart';
import 'package:solfege_app/features/practice/audio/noise_generator.dart';
import 'package:solfege_app/features/scales/services/tone_generator.dart';

void main() {
  test(
      'noise is a valid bounded mono PCM WAV with audible energy and negligible DC',
      () {
    final wav = NoiseGenerator.wav(seed: 19, durationMs: 700);
    final data = ByteData.sublistView(wav);
    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
    expect(ascii.decode(wav.sublist(12, 16)), 'fmt ');
    expect(ascii.decode(wav.sublist(36, 40)), 'data');
    expect(data.getUint32(4, Endian.little), wav.length - 8);
    expect(data.getUint16(20, Endian.little), 1);
    expect(data.getUint16(22, Endian.little), 1);
    expect(data.getUint16(34, Endian.little), 16);
    expect(data.getUint32(24, Endian.little), 44100);
    expect(data.getUint32(28, Endian.little), 88200);
    expect(data.getUint16(32, Endian.little), 2);
    expect(data.getUint32(40, Endian.little), 44100 * 700 ~/ 1000 * 2);
    final samples = _samples(wav);
    final peak = samples.map((s) => s.abs()).reduce(max);
    final rms = sqrt(
        samples.map((s) => s * s).reduce((a, b) => a + b) / samples.length);
    final dc = samples.reduce((a, b) => a + b) / samples.length;
    expect(peak, lessThanOrEqualTo(practiceAudioVolume + 1 / 32767));
    expect(rms, greaterThan(0.1));
    expect(dc.abs(), lessThan(1 / 32767));
    expect(samples.first, 0);
    expect(samples.last, 0);
    // Smooth onset/offset: the first/last millisecond stays near zero.
    expect(samples.take(44).map((s) => s.abs()).reduce(max), lessThan(0.003));
    expect(samples.skip(samples.length - 44).map((s) => s.abs()).reduce(max),
        lessThan(0.003));
  });

  test('seed controls reproducible noise without collapsing different signals',
      () {
    final a = NoiseGenerator.wav(seed: 42);
    expect(NoiseGenerator.wav(seed: 42), orderedEquals(a));
    expect(NoiseGenerator.wav(seed: 43), isNot(orderedEquals(a)));
    expect(_samples(NoiseGenerator.wav(seed: 0)).any((s) => s != 0), isTrue);
  });

  test('noise has no strong pitch periodicity while a generated tone does', () {
    final noise = _samples(NoiseGenerator.wav(seed: 42));
    final tone = _samples(ToneGenerator.wavFromMidi(69, durationMs: 700));
    // A4 repeats approximately every 100 samples at 44.1 kHz. Noise must not
    // accidentally act as another periodic tone at that pitch.
    expect(_correlation(tone, 100), greaterThan(0.95));
    expect(_correlation(noise, 100).abs(), lessThan(0.05));
    expect(const NoiseEvent(1).volume, practiceAudioVolume);
    expect(const NoteEvent(69).volume, practiceAudioVolume);
  });

  test('invalid duration and gain are rejected before writing PCM', () {
    expect(
        () => NoiseGenerator.wav(seed: 1, durationMs: 0), throwsArgumentError);
    expect(() => NoiseGenerator.wav(seed: 1, volume: 1.1), throwsArgumentError);
    expect(() => NoiseGenerator.wav(seed: 1, volume: double.nan),
        throwsArgumentError);
  });
}

List<double> _samples(Uint8List wav) {
  final bytes = ByteData.sublistView(wav);
  return [
    for (var i = 44; i < wav.length; i += 2)
      bytes.getInt16(i, Endian.little) / 32767
  ];
}

double _correlation(List<double> samples, int lag) {
  var xy = 0.0;
  var xx = 0.0;
  var yy = 0.0;
  for (var i = 2000; i < samples.length - 2000 - lag; i++) {
    final x = samples[i];
    final y = samples[i + lag];
    xy += x * y;
    xx += x * x;
    yy += y * y;
  }
  return xy / sqrt(xx * yy);
}
