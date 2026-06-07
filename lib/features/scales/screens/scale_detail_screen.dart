import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../logic/scale_playback.dart';
import '../models/scale.dart';
import '../models/scale_direction.dart';
import '../services/scale_audio_factory.dart';
import '../services/scale_audio_player.dart';
import '../widgets/scale_degrees_grid.dart';
import '../widgets/scale_educational_card.dart';
import '../widgets/scale_header_card.dart';
import '../widgets/scale_listening_tips_card.dart';
import '../widgets/scale_play_button.dart';
import '../widgets/scale_staff_card.dart';

class ScaleDetailScreen extends StatefulWidget {
  ScaleDetailScreen({
    super.key,
    required this.scale,
    ScaleAudioPlayer? audioPlayer,
  }) : audioPlayer = audioPlayer ?? ScaleAudioFactory.createDefault();

  final Scale scale;
  final ScaleAudioPlayer audioPlayer;

  @override
  State<ScaleDetailScreen> createState() => _ScaleDetailScreenState();
}

class _ScaleDetailScreenState extends State<ScaleDetailScreen> {
  late final ScalePlayback _playback = ScalePlayback(widget.audioPlayer);

  @override
  void initState() {
    super.initState();
    _playback.addListener(_onPlaybackChanged);
  }

  @override
  void dispose() {
    _playback.removeListener(_onPlaybackChanged);
    _playback.disposePlayer();
    super.dispose();
  }

  void _onPlaybackChanged() => setState(() {});

  Scale get scale => widget.scale;

  Future<void> _play(ScaleDirection direction) async {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(_playback.playbackMessage(scale, direction)),
          duration: const Duration(seconds: 2),
        ),
      );

    await _playback.play(scale, direction);
  }

  @override
  Widget build(BuildContext context) {
    final playingDirection = _playback.activeDirection;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          scale.name,
          maxLines: 2,
          overflow: TextOverflow.visible,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            ScaleHeaderCard(scale: scale),
            const SizedBox(height: 20),
            ScaleEducationalCard(scale: scale),
            const SizedBox(height: 20),
            ScaleStaffCard(scale: scale),
            const SizedBox(height: 28),
            Text(
              'Ступени',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ScaleDegreesGrid(scale: scale),
            const SizedBox(height: 32),
            Text(
              'Описание',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              scale.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 32),
            ScalePlayButton(
              direction: ScaleDirection.ascending,
              isLoading: playingDirection == ScaleDirection.ascending,
              onPressed: () => _play(ScaleDirection.ascending),
            ),
            const SizedBox(height: 12),
            ScalePlayButton(
              direction: ScaleDirection.descending,
              isLoading: playingDirection == ScaleDirection.descending,
              onPressed: () => _play(ScaleDirection.descending),
            ),
            const SizedBox(height: 12),
            ScalePlayButton(
              direction: ScaleDirection.upDown,
              isLoading: playingDirection == ScaleDirection.upDown,
              onPressed: () => _play(ScaleDirection.upDown),
            ),
            const SizedBox(height: 32),
            ScaleListeningTipsCard(tips: scale.listeningTips),
          ],
        ),
      ),
    );
  }
}
