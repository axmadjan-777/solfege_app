import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../data/song_repository.dart';
import '../models/song.dart';
import '../screens/note_trainer_screen.dart';
import 'trainer_palette.dart';

class WarmupSection extends StatefulWidget {
  const WarmupSection({
    super.key,
    required this.userId,
    this.repository,
    this.onOpen,
  });

  final String userId;
  final SongRepository? repository;
  final ValueChanged<PlayableSong>? onOpen;

  @override
  State<WarmupSection> createState() => _WarmupSectionState();
}

class _WarmupSectionState extends State<WarmupSection> {
  late SongRepository _repository = widget.repository ?? _defaultRepository();
  List<PlayableSong> _songs = [];
  String? _warning;
  var _loading = true;

  SongRepository _defaultRepository() {
    if (!SupabaseConfig.isConfigured) return MemorySongRepository();
    try {
      return SupabaseSongRepository(client: SupabaseClientProvider.client);
    } catch (_) {
      return MemorySongRepository();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final songs = await _repository.fetchSongsWithProgress(widget.userId);
      if (!mounted) return;
      setState(() {
        _songs = songs;
        _loading = false;
        _warning = null;
      });
    } catch (_) {
      final fallback = MemorySongRepository();
      final songs = await fallback.fetchSongsWithProgress(widget.userId);
      if (!mounted) return;
      setState(() {
        _repository = fallback;
        _songs = songs;
        _loading = false;
        _warning = 'Таблица songs ещё не создана. Показан набор из программы.';
      });
    }
  }

  Future<void> _open(PlayableSong song) async {
    if (widget.onOpen != null) {
      widget.onOpen!(song);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteTrainerScreen(
          userId: widget.userId,
          initialSongId: song.id,
          repository: _repository,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🎶 Музыкальная разминка',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Сыграй легендарные хиты по нотам и прокачай музыкальный слух!',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (_warning != null) ...[
          const SizedBox(height: 8),
          Text(_warning!, style: const TextStyle(color: TrainerPalette.amber)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 228,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _songs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final song = _songs[index];
                    return _SongCard(song: song, onPressed: () => _open(song));
                  },
                ),
        ),
      ],
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({required this.song, required this.onPressed});

  final PlayableSong song;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = switch (song.difficulty) {
      SongDifficulty.easy => TrainerPalette.green,
      SongDifficulty.medium => TrainerPalette.amber,
      SongDifficulty.hard => TrainerPalette.red,
    };
    return SizedBox(
      width: 220,
      child: Card(
        key: Key('song-card-${song.id}'),
        color: TrainerPalette.card,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(song.artist, style: const TextStyle(color: TrainerPalette.muted)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  song.difficulty.label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: song.isCompleted ? null : onPressed,
                  child: Text(
                    song.isCompleted ? '🏆 Освоено! (+50 XP)' : '🎯 Попробуй повторить',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
