import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../data/song_repository.dart';
import '../audio/note_player.dart';
import '../models/song.dart';
import '../screens/note_trainer_screen.dart';
import 'trainer_palette.dart';

class WarmupSection extends StatefulWidget {
  const WarmupSection({
    super.key,
    required this.userId,
    this.repository,
    this.onOpen,
    this.player,
    this.wait,
    this.userChanges,
  });

  final String userId;
  final SongRepository? repository;
  final ValueChanged<PlayableSong>? onOpen;
  final NotePlayer? player;
  final Future<void> Function(Duration)? wait;
  final Stream<String?>? userChanges;

  @override
  State<WarmupSection> createState() => _WarmupSectionState();
}

class _WarmupSectionState extends State<WarmupSection> {
  late SongRepository _repository = widget.repository ?? _defaultRepository();
  List<PlayableSong> _songs = [];
  String? _warning;
  var _loading = true;
  var _loadGeneration = 0;
  var _ownerInvalid = false;
  StreamSubscription<String?>? _userSubscription;

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
    _subscribeToOwner();
    _load();
  }

  @override
  void didUpdateWidget(covariant WarmupSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.repository != widget.repository) {
      _repository = widget.repository ?? _defaultRepository();
      _songs = [];
      _loading = true;
      _warning = null;
      _ownerInvalid = false;
      _subscribeToOwner();
      _load();
    } else if (oldWidget.userChanges != widget.userChanges) {
      _subscribeToOwner();
    }
  }

  void _invalidateOwner() {
    _loadGeneration += 1;
    _ownerInvalid = true;
    _songs = [];
    _loading = false;
    _warning = 'Сессия изменилась. Откройте разминку заново из своего профиля.';
  }

  void _subscribeToOwner() {
    _userSubscription?.cancel();
    final owner = widget.userId;
    final repository = _repository;
    final changes = widget.userChanges ??
        (repository is SupabaseSongRepository
            ? repository.client.auth.onAuthStateChange
                .map((state) => state.session?.user.id)
            : null);
    if (repository is SupabaseSongRepository &&
        repository.client.auth.currentUser?.id != owner) {
      _invalidateOwner();
    }
    _userSubscription = changes?.listen((userId) {
      if (!mounted || widget.userId != owner || userId == owner) {
        return;
      }
      setState(_invalidateOwner);
    });
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    _userSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_ownerInvalid) return;
    final generation = ++_loadGeneration;
    final userId = widget.userId;
    final repository = _repository;
    try {
      final songs = await repository.fetchSongsWithProgress(userId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _songs = songs;
        _loading = false;
        _warning = songs.isEmpty
            ? 'Песен пока нет. Попробуйте загрузить ещё раз.'
            : null;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _songs = [];
        _loading = false;
        _warning =
            'Не удалось загрузить песни и сохранённые результаты. Проверьте соединение и повторите.';
      });
    }
  }

  Future<void> _open(PlayableSong song) async {
    if (_ownerInvalid) return;
    if (widget.onOpen != null) {
      widget.onOpen!(song);
      return;
    }
    final userId = widget.userId;
    final repository = _repository;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteTrainerScreen(
          userId: userId,
          initialSongId: song.id,
          repository: repository,
          player: widget.player,
          wait: widget.wait,
        ),
      ),
    );
    if (mounted && userId == widget.userId && repository == _repository) {
      await _load();
    }
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
          if (!_ownerInvalid)
            TextButton(
                onPressed: _load, child: const Text('Повторить загрузку')),
        ],
        if (_repository is MemorySongRepository)
          const Text(
              'В этом режиме результат сохранится только пока открыт профиль.'),
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
              Text(song.artist,
                  style: const TextStyle(color: TrainerPalette.muted)),
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
                    song.isCompleted
                        ? '🏆 Освоено! (+50 XP)'
                        : '🎯 Попробуй повторить',
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
