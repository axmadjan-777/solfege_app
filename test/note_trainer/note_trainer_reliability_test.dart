import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfege_app/features/auth/models/musician_level.dart';
import 'package:solfege_app/features/auth/models/user_profile.dart';
import 'package:solfege_app/features/auth/services/auth_service.dart';
import 'package:solfege_app/features/auth/services/profile_service.dart';
import 'package:solfege_app/features/note_trainer/audio/note_player.dart';
import 'package:solfege_app/features/note_trainer/data/song_catalog.dart';
import 'package:solfege_app/features/note_trainer/data/song_repository.dart';
import 'package:solfege_app/features/note_trainer/logic/note_trainer_controller.dart';
import 'package:solfege_app/features/note_trainer/models/song.dart';
import 'package:solfege_app/features/note_trainer/screens/note_trainer_screen.dart';
import 'package:solfege_app/features/note_trainer/widgets/warmup_section.dart';
import 'package:solfege_app/features/profile/screens/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Player implements NotePlayer {
  final played = <String>[];
  Completer<void>? gate;
  bool fail = false;

  @override
  Future<void> play(String note) async {
    played.add(note);
    if (fail) throw StateError('audio unavailable');
    await gate?.future;
  }
}

class _Repository extends MemorySongRepository {
  Completer<void>? saveGate;
  bool failLoad = false;
  bool failSave = false;
  int saves = 0;

  @override
  Future<List<PlayableSong>> fetchSongsWithProgress(String userId) async {
    if (failLoad) throw StateError('network unavailable');
    return super.fetchSongsWithProgress(userId);
  }

  @override
  Future<void> saveProgress(String userId, String songId) async {
    saves += 1;
    await saveGate?.future;
    if (failSave) throw StateError('transaction failed');
    await super.saveProgress(userId, songId);
  }
}

class _Auth extends AuthService {
  String userId = 'A';
  @override
  User? getCurrentUser() => User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      email: '$userId@example.com',
      createdAt: '2026-11-05T00:00:00Z');
}

class _DelayedReads extends MemorySongRepository {
  final reads = <String, Completer<List<PlayableSong>>>{};

  @override
  Future<List<PlayableSong>> fetchSongsWithProgress(String userId) =>
      reads.putIfAbsent(userId, Completer<List<PlayableSong>>.new).future;
}

class _Profile extends ProfileService {
  @override
  Future<UserProfile?> getCurrentProfile() async => const UserProfile(
      id: 'A',
      displayName: 'Музыкант',
      age: 25,
      musicianLevel: MusicianLevel.beginner,
      onboardingCompleted: true);
}

NoteTrainerController _controller(_Repository repository, _Player player) =>
    NoteTrainerController(
        repository: repository,
        userId: 'A',
        player: player,
        wait: (_) async {},
        onMiss: () {});

Future<void> _finish(NoteTrainerController controller) async {
  await controller.onKeyTap('G4');
  await controller.onKeyTap('F4');
  await controller.onKeyTap('F4');
}

void main() {
  testWidgets(
      'warmup forwards owner changes to the pushed memory trainer route',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();
    final changes = StreamController<String?>.broadcast();
    addTearDown(changes.close);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: WarmupSection(
      userId: 'A',
      repository: repository,
      userChanges: changes.stream,
      player: _Player(),
      wait: (_) async {},
    ))));
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('song-card-yesterday'));
    await tester
        .tap(find.descendant(of: card, matching: find.byType(FilledButton)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(NoteTrainerScreen), findsOneWidget);
    changes.add('B');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('trainer-error')), findsOneWidget);
    expect(find.text('Yesterday'), findsNothing);
    for (final note in ['G4', 'F4', 'F4']) {
      final key = find.byKey(Key('piano-key-$note'));
      await tester.ensureVisible(key);
      expect(key.hitTestable(), findsOneWidget);
      await tester.tap(key);
      await tester.pump();
    }
    expect(repository.saves, 0);
    expect((await repository.fetchSongsWithProgress('A')).first.isCompleted,
        isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('rapid taps cannot count the same awaited note twice', () async {
    final repository = _Repository();
    final player = _Player();
    final controller = _controller(repository, player);
    await controller.load();
    player.gate = Completer<void>();
    final first = controller.onKeyTap('G4');
    await controller.onKeyTap('G4');
    expect(controller.currentNoteIndex, 0);
    expect(controller.totalPlayed, 1);
    player.gate!.complete();
    await first;
    expect(controller.currentNoteIndex, 1);
    expect(repository.saves, 0);
    controller.dispose();
  });

  test('an old playback completion cannot advance a newly selected song',
      () async {
    final repository = _Repository();
    final player = _Player();
    final controller = _controller(repository, player);
    await controller.load();
    final gate = player.gate = Completer<void>();
    final oldTap = controller.onKeyTap('G4');
    player.gate = null;
    await controller.selectSong(songCatalog[1]);
    gate.complete();
    await oldTap;
    expect(controller.song!.id, 'bohemian-rhapsody');
    expect(controller.currentNoteIndex, 0);
    expect(controller.phase, TrainerPhase.playing);
    controller.dispose();
  });

  test(
      'save failure is truthful and retry saves once without replaying the motif',
      () async {
    final repository = _Repository()..failSave = true;
    final controller = _controller(repository, _Player());
    await controller.load();
    await _finish(controller);
    expect(controller.phase, TrainerPhase.saveFailed);
    expect(controller.song!.isCompleted, isFalse);
    expect(controller.saveError, isNotNull);
    expect((await repository.fetchSongsWithProgress('A')).first.isCompleted,
        isFalse);
    repository.failSave = false;
    await controller.retrySave();
    await controller.retrySave();
    expect(controller.phase, TrainerPhase.success);
    expect(repository.saves, 2,
        reason: 'One failed request and one successful retry');
    expect((await repository.fetchSongsWithProgress('A')).first.score, 50);
    controller.dispose();
  });

  test(
      'late save does not overwrite selection and does not notify after disposal',
      () async {
    final repository = _Repository()..saveGate = Completer<void>();
    final controller = _controller(repository, _Player());
    await controller.load();
    final completion = _finish(controller);
    await Future<void>.delayed(Duration.zero);
    expect(controller.phase, TrainerPhase.saving);
    await controller.selectSong(songCatalog[1]);
    repository.saveGate!.complete();
    await completion;
    expect(controller.song!.id, 'bohemian-rhapsody');
    expect(controller.currentNoteIndex, 0);
    expect(controller.phase, TrainerPhase.playing);
    repository.saveGate = Completer<void>();
    await controller.selectSong(songCatalog.first);
    final late = _finish(controller);
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    repository.saveGate!.complete();
    await late;
  });

  test(
      'load and audio failures allow an explicit retry; owner change clears stale data',
      () async {
    final repository = _Repository()..failLoad = true;
    final player = _Player();
    final controller = _controller(repository, player);
    await controller.load();
    expect(controller.phase, TrainerPhase.error);
    repository.failLoad = false;
    player.fail = true;
    await controller.load();
    expect(controller.phase, TrainerPhase.error);
    player.fail = false;
    await controller.load();
    expect(controller.phase, TrainerPhase.playing);
    controller.invalidateSession();
    expect(controller.song, isNull);
    expect(controller.songs, isEmpty);
    await controller.onKeyTap('G4');
    await controller.load();
    expect(controller.phase, TrainerPhase.error);
    expect(repository.saves, 0);
    controller.dispose();
  });

  testWidgets(
      'profile → warmup → real piano → saved completion → reload and second account',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();
    final auth = _Auth();
    final player = _Player();
    Widget profile({Key? key}) => MaterialApp(
        home: ProfileScreen(
            key: key,
            authService: auth,
            profileService: _Profile(),
            songRepository: repository,
            notePlayer: player,
            noteWait: (_) async {}));
    await tester.pumpWidget(profile());
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('song-card-yesterday'));
    await tester
        .tap(find.descendant(of: card, matching: find.byType(FilledButton)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(NoteTrainerScreen), findsOneWidget);
    for (final note in ['G4', 'F4', 'F4']) {
      final key = find.byKey(Key('piano-key-$note'));
      await tester.ensureVisible(key);
      await tester.pump();
      await tester.tap(key);
      await tester.pump();
    }
    expect(find.byKey(const Key('trainer-saved')), findsOneWidget);
    expect(player.played, ['G4', 'F4', 'F4', 'G4', 'F4', 'F4']);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('🏆 Освоено! (+50 XP)'), findsOneWidget);
    await tester.pumpWidget(profile(key: const Key('reopened-profile')));
    await tester.pumpAndSettle();
    expect(find.text('🏆 Освоено! (+50 XP)'), findsOneWidget);
    auth.userId = 'B';
    await tester.pumpWidget(profile(key: const Key('second-user')));
    await tester.pumpAndSettle();
    expect(find.text('🏆 Освоено! (+50 XP)'), findsNothing);
    expect((await repository.fetchSongsWithProgress('A')).first.isCompleted,
        isTrue);
  });

  testWidgets(
      'warmup keeps a cloud failure visible and retries the same repository',
      (tester) async {
    final repository = _Repository()..failLoad = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: WarmupSection(userId: 'A', repository: repository))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Не удалось загрузить песни'), findsOneWidget);
    expect(find.byKey(const Key('song-card-yesterday')), findsNothing);
    repository.failLoad = false;
    await tester.tap(find.text('Повторить загрузку'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-card-yesterday')), findsOneWidget);
  });

  testWidgets('a delayed warmup response for A cannot replace the cards of B',
      (tester) async {
    final repository = _DelayedReads();
    Widget warmup(String userId) => MaterialApp(
        home: Scaffold(
            body: WarmupSection(userId: userId, repository: repository)));
    await tester.pumpWidget(warmup('A'));
    await tester.pump();
    await tester.pumpWidget(warmup('B'));
    await tester.pump();
    repository.reads['B']!.complete(songCatalog);
    await tester.pumpAndSettle();
    repository.reads['A']!.complete([
      songCatalog.first.copyWith(isCompleted: true, score: 50),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('🏆 Освоено! (+50 XP)'), findsNothing);
    expect(find.byKey(const Key('song-card-yesterday')), findsOneWidget);
  });

  testWidgets(
      'warmup hides A completion immediately on auth change before B props arrive',
      (tester) async {
    final repository = _Repository();
    await repository.saveProgress('A', 'yesterday');
    final changes = StreamController<String?>.broadcast();
    addTearDown(changes.close);
    Widget warmup(String userId) => MaterialApp(
        home: Scaffold(
            body: WarmupSection(
                userId: userId,
                repository: repository,
                userChanges: changes.stream)));
    await tester.pumpWidget(warmup('A'));
    await tester.pumpAndSettle();
    expect(find.text('🏆 Освоено! (+50 XP)'), findsOneWidget);

    changes.add('B');
    await tester.pump(); // Deliver the asynchronous auth event.
    await tester.pump(); // Render the invalidated owner state.
    expect(find.byKey(const Key('song-card-yesterday')), findsNothing);
    expect(find.text('🏆 Освоено! (+50 XP)'), findsNothing);
    expect(find.textContaining('Сессия изменилась'), findsOneWidget);
    expect(find.text('Повторить загрузку'), findsNothing);

    await tester.pumpWidget(warmup('B'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-card-yesterday')), findsOneWidget);
    expect(find.text('🏆 Освоено! (+50 XP)'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'a late A load after auth change stays hidden until the parent supplies B',
      (tester) async {
    final repository = _DelayedReads();
    final changes = StreamController<String?>.broadcast();
    addTearDown(changes.close);
    Widget warmup(String userId) => MaterialApp(
        home: Scaffold(
            body: WarmupSection(
                userId: userId,
                repository: repository,
                userChanges: changes.stream)));
    await tester.pumpWidget(warmup('A'));
    await tester.pump();
    changes.add('B');
    await tester.pump();
    repository.reads['A']!.complete([
      songCatalog.first.copyWith(isCompleted: true, score: 50),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-card-yesterday')), findsNothing);
    expect(repository.reads.keys, ['A'],
        reason: 'Do not silently rebind the A widget to B');

    await tester.pumpWidget(warmup('B'));
    await tester.pump();
    repository.reads['B']!.complete(songCatalog);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('song-card-yesterday')), findsOneWidget);
    expect(find.text('🏆 Освоено! (+50 XP)'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'a trainer auth change clears the previous owner before pending work completes',
      (tester) async {
    final repository = _Repository();
    final controller = _controller(repository, _Player());
    await controller.load();
    final changes = StreamController<String?>();
    addTearDown(changes.close);
    await tester.pumpWidget(MaterialApp(
        home: NoteTrainerScreen(
            controller: controller, userChanges: changes.stream)));
    await tester.pump();
    changes.add('B');
    await tester.pump();
    expect(controller.sessionExpired, isTrue);
    expect(controller.song, isNull);
    expect(find.byKey(const Key('trainer-error')), findsOneWidget);
    expect(find.text('Yesterday'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
