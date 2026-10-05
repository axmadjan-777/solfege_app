import 'package:flutter/material.dart';

import '../audio/note_player.dart';
import '../data/song_repository.dart';
import '../logic/note_pitch.dart';
import '../logic/note_trainer_controller.dart';
import '../models/song.dart';
import '../widgets/shake_feedback.dart';
import '../widgets/sheet_music_widget.dart';
import '../widgets/trainer_palette.dart';
import '../widgets/virtual_piano_widget.dart';

class NoteTrainerScreen extends StatefulWidget {
  const NoteTrainerScreen({
    super.key,
    this.userId = 'local',
    this.initialSongId,
    this.repository,
    this.player,
    this.controller,
  });

  final String userId;
  final String? initialSongId;
  final SongRepository? repository;
  final NotePlayer? player;
  final NoteTrainerController? controller;

  @override
  State<NoteTrainerScreen> createState() => _NoteTrainerScreenState();
}

class _NoteTrainerScreenState extends State<NoteTrainerScreen> {
  late final NoteTrainerController _controller;
  late final bool _ownsController;
  AssetNotePlayer? _ownedPlayer;
  var _showLabels = true;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      final NotePlayer player;
      if (widget.player != null) {
        player = widget.player!;
      } else {
        _ownedPlayer = AssetNotePlayer();
        player = _ownedPlayer!;
      }
      _controller = NoteTrainerController(
        repository: widget.repository ?? MemorySongRepository(),
        userId: widget.userId,
        player: player,
      );
      _ownsController = true;
      _controller.load(initialSongId: widget.initialSongId);
    }
    _controller.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    if (_ownsController) _controller.dispose();
    _ownedPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = _controller.song;
    final notes = song?.expectedNotes ?? const <String>[];
    final active = _controller.activeNote;
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: TrainerPalette.background,
        colorScheme: const ColorScheme.dark(
          primary: TrainerPalette.green,
          surface: TrainerPalette.card,
        ),
      ),
      child: Scaffold(
        backgroundColor: TrainerPalette.background,
        appBar: AppBar(
          backgroundColor: TrainerPalette.background,
          title: const Text('Нотный тренажёр'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _StaffCard(
              noteLabel: active == null ? '—' : currentNoteLabel(active),
              notes: notes,
              positions: song?.notePositions ?? const [],
              activeIndex: _controller.phase == TrainerPhase.listening
                  ? _controller.highlightIndex
                  : _controller.currentNoteIndex,
              solvedCount: _controller.progressDone,
            ),
            const SizedBox(height: 16),
            _StatsRow(
              title: song?.title ?? '—',
              done: _controller.progressDone,
              total: notes.length,
              played: _controller.totalPlayed,
            ),
            const SizedBox(height: 16),
            const Text('Выберите музыкальный мотив для обучения:'),
            const SizedBox(height: 8),
            _SongMenu(
              songs: _controller.songs,
              selectedId: song?.id,
              onSelected: (id) {
                for (final item in _controller.songs) {
                  if (item.id == id) _controller.selectSong(item);
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: Text('Нажимайте\nклавиши на\nпианино:')),
                const SizedBox(width: 8),
                Flexible(
                  flex: 2,
                  child: ShakeFeedback(
                    tick: _controller.shakeTick,
                    text: _controller.feedback,
                    tone: _controller.tone,
                  ),
                ),
              ],
            ),
            if (_controller.saveError != null) ...[
              const SizedBox(height: 8),
              Text(
                'Прогресс не записался на сервер. На этом устройстве песня отмечена.',
                style: TextStyle(color: TrainerPalette.amber.withValues(alpha: 0.9)),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const Key('piano-eye'),
                tooltip: 'Подсказка',
                onPressed: () => setState(() => _showLabels = !_showLabels),
                icon: Icon(
                  _showLabels ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
              ),
            ),
            VirtualPianoWidget(
              showLabels: _showLabels,
              activeNote: active,
              onTap: (note) => _controller.onKeyTap(note),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.noteLabel,
    required this.notes,
    required this.positions,
    required this.activeIndex,
    required this.solvedCount,
  });

  final String noteLabel;
  final List<String> notes;
  final List<int> positions;
  final int activeIndex;
  final int solvedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TrainerPalette.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Текущая нота: $noteLabel'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.music_note, color: TrainerPalette.line),
              Expanded(
                child: SheetMusicWidget(
                  notes: notes,
                  positions: positions,
                  activeIndex: activeIndex,
                  solvedCount: solvedCount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.title,
    required this.done,
    required this.total,
    required this.played,
  });

  final String title;
  final int done;
  final int total;
  final int played;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(label: 'Мотив', value: title),
        _Stat(label: 'Прогресс нот', value: '$done / $total'),
        _Stat(label: 'Сыграно всего', value: '$played', emphasize: true),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: TrainerPalette.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: emphasize ? TrainerPalette.green : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SongMenu extends StatelessWidget {
  const _SongMenu({
    required this.songs,
    required this.selectedId,
    required this.onSelected,
  });

  final List<PlayableSong> songs;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: TrainerPalette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: selectedId,
          dropdownColor: TrainerPalette.card,
          items: [
            for (final song in songs)
              DropdownMenuItem(value: song.id, child: Text(song.title)),
          ],
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
        ),
      ),
    );
  }
}
