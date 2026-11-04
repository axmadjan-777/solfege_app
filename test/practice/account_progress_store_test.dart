import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfege_app/features/app/main_shell_screen.dart';
import 'package:solfege_app/features/curriculum/data/curriculum_catalog.dart';
import 'package:solfege_app/features/practice/progress/account_progress_store.dart';
import 'package:solfege_app/features/practice/progress/clock.dart';
import 'package:solfege_app/features/practice/progress/error_return.dart';
import 'package:solfege_app/features/practice/progress/practice_book_sync.dart';
import 'package:solfege_app/features/practice/progress/practice_progress_binding.dart';
import 'package:solfege_app/features/practice/progress/progress_store.dart';
import 'package:solfege_app/features/practice/widgets/account_progress_notice.dart';

late CurriculumCatalog catalog;
const a = '10000000-0000-4000-8000-000000000001';
const b = '10000000-0000-4000-8000-000000000002';
final at = DateTime.utc(2026, 11, 5);
int writeSerial = 0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => catalog = _catalog());
  setUp(() {
    writeSerial = 0;
    SharedPreferences.setMockInitialValues({});
  });

  test('A → B → A keeps separate local books and cloud owners', () async {
    var current = a;
    final prefs = await SharedPreferences.getInstance();
    final remote = _Remote();
    final first = _store(prefs, a, () => current, remote: remote);
    first.scheduleNextDayReturn('A-only');
    await first.waitForSync();
    first.close();
    current = b;
    final second = _store(prefs, b, () => current, remote: remote)..startSync();
    await second.waitForSync();
    expect(second.book.returns, isEmpty);
    second.scheduleNextDayReturn('B-only');
    await second.waitForSync();
    second.close();
    current = a;
    await AccountProgressStore.pendingLocalWrites(a);
    final again = _store(prefs, a, () => current, remote: remote)..startSync();
    await again.waitForSync();
    expect(again.book.userId, a);
    expect(again.book.returns.map((r) => r.tag), ['A-only']);
    expect(remote.books[b]!.book.returns.map((r) => r.tag), ['B-only']);
    expect(prefs.containsKey(AccountProgressStore.keyFor(a)), isTrue);
    expect(prefs.containsKey(AccountProgressStore.keyFor(b)), isTrue);
    expect(prefs.containsKey(AccountProgressStore.legacyKey), isFalse);
  });

  test('unowned legacy book is never auto-uploaded; consent retains source',
      () async {
    final raw = jsonEncode(_book('local', 'old').toJson());
    SharedPreferences.setMockInitialValues(
        {AccountProgressStore.legacyKey: raw});
    final prefs = await SharedPreferences.getInstance();
    var current = a;
    final remote = _Remote();
    final store = _store(prefs, a, () => current, remote: remote)..startSync();
    await store.waitForSync();
    expect(store.hasLegacy, isTrue);
    expect(store.book.returns, isEmpty);
    expect(remote.writes, isEmpty);
    await store.importLegacy();
    await store.waitForSync();
    expect(store.book.userId, a);
    expect(remote.books[a]!.book.userId, a);
    expect(remote.books[a]!.book.returns.single.tag, 'old');
    expect(prefs.getString(AccountProgressStore.legacyKey), raw);
    expect(prefs.getString(AccountProgressStore.legacyClaimKey), a);
    store.close();
    current = b;
    final other = _store(prefs, b, () => current);
    expect(other.hasLegacy, isFalse);
    expect(other.book.returns, isEmpty);
    current = a;
    expect(_store(prefs, a, () => current).hasLegacy, isFalse);
  });

  test(
      'stage-only books survive legacy import, cloud, conflict backup and restart',
      () async {
    const stageOnly = ProgressBook(
        userId: 'local',
        competencies: {},
        attempts: [],
        passedStages: {
          'PR-01': [4]
        });
    final raw = jsonEncode(stageOnly.toJson());
    SharedPreferences.setMockInitialValues(
        {AccountProgressStore.legacyKey: raw});
    final prefs = await SharedPreferences.getInstance();
    final remote = _Remote();
    final store = _store(prefs, a, () => a, remote: remote)..startSync();
    await store.waitForSync();
    expect(store.hasLegacy, isTrue);
    await store.importLegacy();
    await store.waitForSync();
    expect(remote.books[a]!.book.passedStages, {
      'PR-01': [4]
    });
    store.markStagePassed('PR-03', 2);
    await store.waitForSync();
    final remoteRevision = remote.books[a]!.revision;
    remote.books[a] = RemotePracticeBook(
        book: const ProgressBook(
            userId: a,
            competencies: {},
            attempts: [],
            passedStages: {
              'PR-08': [3]
            }),
        revision: remoteRevision + 1);
    store.markStagePassed('PR-09', 1);
    await store.waitForSync();
    expect(store.state, AccountSyncState.conflict);
    await store.resolveConflict(useRemote: true);
    expect(store.book.passedStages, {
      'PR-08': [3]
    });
    await store.restoreBackup();
    await store.waitForSync();
    final expected = {
      'PR-01': [4],
      'PR-03': [2],
      'PR-09': [1]
    };
    expect(store.book.passedStages, expected);
    expect(remote.books[a]!.book.passedStages, expected);
    expect(store.book.attempts, isEmpty);
    expect(store.book.competencies, isEmpty);
    store.close();
    await AccountProgressStore.pendingLocalWrites(a);
    final reopened = _store(prefs, a, () => a, remote: remote)..startSync();
    await reopened.waitForSync();
    expect(reopened.book.userId, a);
    expect(reopened.book.passedStages, expected);
    expect(prefs.getString(AccountProgressStore.legacyKey), raw);
  });

  test('declining legacy import does not assign or remove the unowned book',
      () async {
    final raw = jsonEncode(_book('local', 'old').toJson());
    SharedPreferences.setMockInitialValues(
        {AccountProgressStore.legacyKey: raw});
    final prefs = await SharedPreferences.getInstance();
    final store = _store(prefs, a, () => a);
    await store.dismissLegacy();
    expect(store.hasLegacy, isFalse);
    expect(store.book.returns, isEmpty);
    expect(prefs.getString(AccountProgressStore.legacyKey), raw);
    expect(prefs.containsKey(AccountProgressStore.legacyClaimKey), isFalse);
    expect(_store(prefs, a, () => a).hasLegacy, isFalse);
  });

  test('explicit import and restore retain every replaced local copy',
      () async {
    final raw = jsonEncode(_book('local', 'old').toJson());
    SharedPreferences.setMockInitialValues(
        {AccountProgressStore.legacyKey: raw});
    final prefs = await SharedPreferences.getInstance();
    final store = _store(prefs, a, () => a);
    store.scheduleNextDayReturn('current');
    await store.flushLocal();
    await store.importLegacy();
    expect(store.book.returns.single.tag, 'old');
    await store.restoreBackup();
    expect(store.book.returns.single.tag, 'current');
    final copies =
        jsonDecode(prefs.getString('${store.storageKey}:backups')!) as List;
    expect(copies, hasLength(2));
    expect(prefs.getString(AccountProgressStore.legacyKey), raw);
  });

  for (final replacement in [
    'legacy import',
    'cloud choice',
    'backup restore'
  ]) {
    test('$replacement cannot overwrite evidence recorded during backup write',
        () async {
      final legacy = jsonEncode(_book('local', 'legacy').toJson());
      SharedPreferences.setMockInitialValues({
        AccountProgressStore.legacyKey: legacy,
        '${AccountProgressStore.keyFor(a)}:backups':
            jsonEncode([_book(a, 'restore-target').toJson()]),
      });
      final prefs = await SharedPreferences.getInstance();
      final backupStarted = Completer<void>();
      final release = Completer<void>();
      final remote = replacement == 'cloud choice'
          ? (_Remote()
            ..books[a] =
                RemotePracticeBook(book: _book(a, 'server'), revision: 7))
          : null;
      final store = AccountProgressStore(
          preferences: prefs,
          userId: a,
          clock: FixedClock(at),
          rules: catalog.config.masteryRules,
          currentUserId: () => a,
          remote: remote,
          newWriteId: () => '$a-${++writeSerial}',
          writeString: (key, value) async {
            if (key.endsWith(':backups') && !backupStarted.isCompleted) {
              backupStarted.complete();
              await release.future;
            }
            return prefs.setString(key, value);
          });
      Future<void>? replacementAction;
      _cleanupGate(release, store, action: () => replacementAction);
      store.scheduleNextDayReturn('current');
      await store.flushLocal();
      await store.waitForSync();
      final action = replacementAction = switch (replacement) {
        'legacy import' => store.importLegacy(),
        'cloud choice' => store.resolveConflict(useRemote: true),
        _ => store.restoreBackup(),
      };
      final assertion = expectLater(action, throwsStateError);
      await backupStarted.future;
      store.scheduleNextDayReturn('arrived-late');
      await store.flushLocal();
      release.complete();
      await assertion;
      expect(store.book.returns.map((r) => r.tag), ['current', 'arrived-late']);
      final disk = jsonDecode(prefs.getString(store.storageKey)!) as Map;
      expect((disk['book'] as Map)['returns'], hasLength(2));
      expect(prefs.getString(AccountProgressStore.legacyKey), legacy);
      if (remote != null) {
        expect(remote.books[a]!.book.returns.single.tag, 'server');
      }
    });
  }

  test(
      'pending legacy consent cannot transfer the book to a newly signed-in user',
      () async {
    final raw = jsonEncode(_book('local', 'legacy').toJson());
    SharedPreferences.setMockInitialValues(
        {AccountProgressStore.legacyKey: raw});
    final prefs = await SharedPreferences.getInstance();
    var current = a;
    final started = Completer<void>();
    final release = Completer<void>();
    final store = AccountProgressStore(
        preferences: prefs,
        userId: a,
        clock: FixedClock(at),
        rules: catalog.config.masteryRules,
        currentUserId: () => current,
        writeString: (key, value) async {
          if (key == AccountProgressStore.legacyClaimKey) {
            started.complete();
            await release.future;
          }
          return prefs.setString(key, value);
        });
    final importing = store.importLegacy();
    final assertion =
        expectLater(importing, throwsA(isA<PracticeAccountChanged>()));
    _cleanupGate(release, store, action: () => importing);
    await started.future;
    current = b;
    store.close();
    final other = _store(prefs, b, () => current);
    release.complete();
    await assertion;
    expect(other.book.returns, isEmpty);
    expect(other.hasLegacy, isFalse);
    expect(prefs.getString(AccountProgressStore.legacyKey), raw);
    current = a;
    final returned = _store(prefs, a, () => current);
    expect(returned.hasLegacy, isTrue);
    await returned.importLegacy();
    expect(returned.book.returns.single.tag, 'legacy');
  });

  test('consecutive replacement actions cannot race their backup writes',
      () async {
    SharedPreferences.setMockInitialValues({
      AccountProgressStore.legacyKey:
          jsonEncode(_book('local', 'legacy').toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    final started = Completer<void>();
    final release = Completer<void>();
    final store = AccountProgressStore(
        preferences: prefs,
        userId: a,
        clock: FixedClock(at),
        rules: catalog.config.masteryRules,
        currentUserId: () => a,
        writeString: (key, value) async {
          if (key.endsWith(':backups') && !started.isCompleted) {
            started.complete();
            await release.future;
          }
          return prefs.setString(key, value);
        });
    store.scheduleNextDayReturn('current');
    await store.flushLocal();
    final importing = store.importLegacy();
    _cleanupGate(release, store, action: () => importing);
    await started.future;
    await expectLater(store.restoreBackup(), throwsStateError);
    release.complete();
    await importing;
    expect(store.book.returns.single.tag, 'legacy');
    expect(jsonDecode(prefs.getString('${store.storageKey}:backups')!) as List,
        hasLength(1));
  });

  test('a differently owned v2 envelope is rejected and retained untouched',
      () async {
    final raw = jsonEncode({'user_id': b, 'book': _book(b, 'B').toJson()});
    SharedPreferences.setMockInitialValues(
        {AccountProgressStore.keyFor(a): raw});
    final prefs = await SharedPreferences.getInstance();
    expect(() => _store(prefs, a, () => a), throwsStateError);
    expect(prefs.getString(AccountProgressStore.keyFor(a)), raw);
  });

  test('pending pull cannot adopt A data after an auth switch', () async {
    var current = a;
    final started = Completer<void>();
    final response = Completer<RemotePracticeBook?>();
    final remote = _Remote()
      ..beforePull = (_) {
        started.complete();
        return response.future;
      };
    final prefs = await SharedPreferences.getInstance();
    final store = _store(prefs, a, () => current, remote: remote)..startSync();
    await started.future;
    current = b;
    store.close();
    response
        .complete(RemotePracticeBook(book: _book(a, 'A-cloud'), revision: 1));
    await store.waitForSync();
    expect(store.state, AccountSyncState.closed);
    expect(store.book.returns, isEmpty);
    expect(remote.writes, isEmpty);
    expect(_store(prefs, b, () => current).book.returns, isEmpty);
  });

  test('in-flight A save never uploads to B; returning to A acknowledges retry',
      () async {
    var current = a;
    final remote = _Remote();
    final prefs = await SharedPreferences.getInstance();
    final store = _store(prefs, a, () => current, remote: remote)..startSync();
    await store.waitForSync();
    final started = Completer<void>();
    final release = Completer<void>();
    remote.beforePush = (_) {
      started.complete();
      return release.future;
    };
    store.scheduleNextDayReturn('A-evidence');
    await started.future;
    current = b;
    store.close();
    release.complete();
    await store.waitForSync();
    expect(remote.books.containsKey(b), isFalse);
    expect(remote.writes.single.userId, a);
    current = a;
    await AccountProgressStore.pendingLocalWrites(a);
    remote.beforePush = null;
    final returned = _store(prefs, a, () => current, remote: remote)
      ..startSync();
    await returned.waitForSync();
    expect(returned.hasPendingChanges, isFalse);
    expect(returned.book.returns.single.tag, 'A-evidence');
    expect(remote.writes, hasLength(1));
    store.scheduleNextDayReturn('stale-route');
    expect(store.book.returns.map((r) => r.tag), ['A-evidence']);
  });

  test('overlapping edits serialize RPCs and do not block durable disk writes',
      () async {
    final remote = _Remote();
    final prefs = await SharedPreferences.getInstance();
    final store = _store(prefs, a, () => a, remote: remote)..startSync();
    await store.waitForSync();
    final started = Completer<void>();
    final release = Completer<void>();
    remote.beforePush = (_) async {
      if (!started.isCompleted) {
        started.complete();
        await release.future;
      }
    };
    store.scheduleNextDayReturn('first');
    await started.future;
    store.scheduleNextDayReturn('second');
    store.scheduleNextDayReturn('third');
    await store.flushLocal();
    final disk = jsonDecode(prefs.getString(store.storageKey)!) as Map;
    expect((disk['book'] as Map)['returns'], hasLength(3));
    expect(remote.writes, hasLength(1));
    release.complete();
    await store.waitForSync();
    expect(remote.maxActive, 1);
    expect(remote.writes.map((w) => w.expectedRevision), [0, 1]);
    expect(remote.books[a]!.book.returns, hasLength(3));
    expect(store.hasPendingChanges, isFalse);
  });

  test('failed push stays durable and is retried after a restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final remote = _Remote()..failNext = true;
    final store = _store(prefs, a, () => a, remote: remote);
    store.scheduleNextDayReturn('offline');
    await store.waitForSync();
    expect(store.state, AccountSyncState.error);
    expect(store.hasPendingChanges, isTrue);
    expect(remote.books, isEmpty);
    store.close();
    final restarted = _store(prefs, a, () => a, remote: remote)..startSync();
    await restarted.waitForSync();
    expect(remote.books[a]!.book.returns.single.tag, 'offline');
    expect(restarted.hasPendingChanges, isFalse);
  });

  test('timeout retry and a late original HTTP reply keep a single version',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final remote = _Remote();
    final release = Completer<void>();
    final started = Completer<void>();
    final deadline = Completer<int>();
    Future<int>? original;
    var held = false;
    remote.beforePush = (_) async {
      if (!held) {
        held = true;
        started.complete();
        await release.future;
      }
    };
    final store = AccountProgressStore(
        preferences: prefs,
        userId: a,
        clock: FixedClock(at),
        rules: catalog.config.masteryRules,
        currentUserId: () => a,
        remote: remote,
        waitForSave: (request, _) {
          if (original == null) {
            original = request;
            request.then<void>((value) {
              if (!deadline.isCompleted) deadline.complete(value);
            }, onError: (Object error, StackTrace stack) {
              if (!deadline.isCompleted) deadline.completeError(error, stack);
            });
            return deadline.future;
          }
          return request;
        },
        newWriteId: () => '$a-${++writeSerial}');
    addTearDown(() async {
      if (!release.isCompleted) release.complete();
      await store.waitForSync();
      await store.flushLocal();
      store.close();
    });
    store.scheduleNextDayReturn('late');
    await started.future;
    expect(held, isTrue);
    deadline.completeError(TimeoutException('Controlled deadline'));
    await store.waitForSync();
    expect(store.state, AccountSyncState.error);
    expect(store.hasPendingChanges, isTrue);
    await store.retrySync();
    expect(remote.books[a]!.revision, 1);
    expect(remote.maxActive, 2); // The old HTTP request was not cancelled.
    release.complete();
    await original;
    expect(remote.active, 0);
    expect(remote.books[a]!.revision, 1);
    expect(remote.books[a]!.book.returns.single.tag, 'late');
    expect(store.hasPendingChanges, isFalse);
  });

  test('a rejected local write is handled and never reported as cloud success',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final remote = _Remote();
    var fail = true;
    final store = AccountProgressStore(
        preferences: prefs,
        userId: a,
        clock: FixedClock(at),
        rules: catalog.config.masteryRules,
        currentUserId: () => a,
        remote: remote,
        writeString: (key, value) => fail
            ? Future<bool>.error(StateError('simulated disk failure'))
            : prefs.setString(key, value));
    store.scheduleNextDayReturn('not-yet-durable');
    await store.waitForSync();
    expect(store.state, AccountSyncState.error);
    expect(
        store.message, contains('Не удалось сохранить прогресс на устройстве'));
    expect(store.hasPendingChanges, isTrue);
    expect(remote.writes, isEmpty);
    fail = false;
    await store.retrySync();
    expect(store.state, AccountSyncState.synced);
    expect(remote.books[a]!.book.returns.single.tag, 'not-yet-durable');
    expect(store.hasPendingChanges, isFalse);
  });

  test('a lost reply is acknowledged by write ID without duplicate commit',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final remote = _Remote()..loseReply = true;
    final store = _store(prefs, a, () => a, remote: remote);
    store.scheduleNextDayReturn('once');
    await store.waitForSync();
    expect(store.state, AccountSyncState.error);
    expect(remote.books[a]!.revision, 1);
    await store.retrySync();
    expect(store.state, AccountSyncState.synced);
    expect(store.hasPendingChanges, isFalse);
    expect(remote.writes, hasLength(1));
  });

  test(
      'CAS conflict retains both copies and explicit resolution saves a backup',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final remote = _Remote();
    final store = _store(prefs, a, () => a, remote: remote)..startSync();
    await store.waitForSync();
    remote.books[a] =
        RemotePracticeBook(book: _book(a, 'other-device'), revision: 1);
    store.scheduleNextDayReturn('this-device');
    await store.waitForSync();
    expect(store.state, AccountSyncState.conflict);
    expect(store.book.returns.single.tag, 'this-device');
    expect(remote.books[a]!.book.returns.single.tag, 'other-device');
    await store.resolveConflict(useRemote: false);
    expect(remote.books[a]!.book.returns.single.tag, 'this-device');
    final backups =
        jsonDecode(prefs.getString('${store.storageKey}:backups')!) as List;
    expect(((backups.single as Map)['returns'] as List).single['tag'],
        'other-device');
    expect(remote.history.single.book.returns.single.tag, 'other-device');
  });

  test('old cloud book with unproved owner also requires explicit import',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final remote = _Remote()
      ..books[a] =
          RemotePracticeBook(book: _book('local', 'unowned'), revision: 4);
    final store = _store(prefs, a, () => a, remote: remote)..startSync();
    await store.waitForSync();
    expect(store.state, AccountSyncState.legacyRemote);
    expect(store.book.returns, isEmpty);
    store.scheduleNextDayReturn('new');
    await store.flushLocal();
    expect(remote.writes, isEmpty);
    await store.resolveConflict(useRemote: true);
    expect(remote.books[a]!.book.userId, a);
    expect(remote.books[a]!.book.returns.single.tag, 'unowned');
    expect(remote.history.single.book.userId, 'local');
  });

  testWidgets('legacy import UI requires confirmation and permits cancellation',
      (tester) async {
    final raw = jsonEncode(_book('local', 'old').toJson());
    SharedPreferences.setMockInitialValues(
        {AccountProgressStore.legacyKey: raw});
    final prefs = await SharedPreferences.getInstance();
    final store = _store(prefs, a, () => a);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AccountProgressNotice(store: store))));
    await tester.tap(find.text('Импортировать'));
    await tester.pumpAndSettle();
    expect(store.book.returns, isEmpty);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(store.book.returns, isEmpty);
    await tester.tap(find.text('Импортировать'));
    await tester.pumpAndSettle();
    final imported = Completer<void>();
    void onImported() {
      if (!store.hasLegacy && !imported.isCompleted) imported.complete();
    }

    store.addListener(onImported);
    addTearDown(() => store.removeListener(onImported));
    await tester.tap(find.text('Подтвердить'));
    await tester.pump();
    // The dialog continuation lives in the widget fake zone, while an earlier
    // account's completed disk tail may belong to a real async test zone.
    // Drive both queues instead of waiting for a fake-zone future in runAsync.
    for (var turn = 0; turn < 20 && !imported.isCompleted; turn += 1) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    expect(imported.isCompleted, isTrue,
        reason:
            'Explicit import must complete while both async queues are driven');
    await tester.pumpAndSettle();
    expect(store.book.userId, a);
    expect(store.book.returns.single.tag, 'old');
    expect(prefs.getString(AccountProgressStore.legacyKey), raw);
  });

  testWidgets('auth replacement invalidates pending shell load and old routes',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final identity = ValueNotifier<String?>(a);
    final load = Completer<PracticeProgressBinding>();
    final store = _store(prefs, a, () => identity.value);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: MainShellScreen(
          userId: a,
          sessionUserId: identity,
          progressLoader: (_, __) => load.future,
        )));
    final lessonRoute = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Старый урок')));
    navigator.currentState!.push(lessonRoute);
    await tester.pump();
    await tester.pump(lessonRoute.transitionDuration);
    await tester.pump();
    expect(find.text('Старый урок'), findsOneWidget);
    var removed = false;
    lessonRoute.completed.then((_) => removed = true);
    identity.value = b;
    // Wait for this route's overlay disposal, not for the loading spinner.
    for (var frame = 0; frame < 120 && !removed; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(removed, isTrue,
        reason: 'The old account route must finish removal');
    expect(navigator.currentState!.canPop(), isFalse);
    expect(find.text('Старый урок'), findsNothing);
    identity.value = a;
    load.complete(PracticeProgressBinding(
        catalog: catalog, clock: FixedClock(at), progress: store));
    await tester.pump();
    await tester.pump();
    expect(store.state, AccountSyncState.closed);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    identity.dispose();
  });
}

AccountProgressStore _store(
    SharedPreferences prefs, String owner, String? Function() current,
    {PracticeBookRemote? remote}) {
  return AccountProgressStore(
      preferences: prefs,
      userId: owner,
      clock: FixedClock(at),
      rules: catalog.config.masteryRules,
      currentUserId: current,
      remote: remote,
      newWriteId: () => '$owner-${++writeSerial}');
}

void _cleanupGate(Completer<void> release, AccountProgressStore store,
    {Future<void>? Function()? action}) {
  addTearDown(() async {
    if (!release.isCompleted) release.complete();
    try {
      await action?.call();
    } catch (_) {
      // The main test asserts the action outcome; cleanup only releases its gate.
    }
    await store.waitForSync();
    await store.flushLocal();
    store.close();
  });
}

ProgressBook _book(String owner, String tag) => ProgressBook(
    userId: owner,
    competencies: {},
    attempts: [],
    returns: [ScheduledReturn(tag: tag, dueAt: at)]);

class _Write {
  const _Write(this.userId, this.book, this.expectedRevision, this.writeId);
  final String userId;
  final ProgressBook book;
  final int expectedRevision;
  final String writeId;
}

class _Remote implements PracticeBookRemote {
  final books = <String, RemotePracticeBook>{};
  final writes = <_Write>[];
  final history = <RemotePracticeBook>[];
  Future<RemotePracticeBook?> Function(String)? beforePull;
  Future<void> Function(_Write)? beforePush;
  bool failNext = false;
  bool loseReply = false;
  int active = 0;
  int maxActive = 0;
  @override
  Future<RemotePracticeBook?> pull(String userId) async =>
      beforePull == null ? books[userId] : await beforePull!(userId);
  @override
  Future<int> push(
      {required String userId,
      required ProgressBook book,
      required int expectedRevision,
      required String writeId}) async {
    final write = _Write(userId, book, expectedRevision, writeId);
    writes.add(write);
    active += 1;
    if (active > maxActive) maxActive = active;
    try {
      await beforePush?.call(write);
      if (failNext) {
        failNext = false;
        throw StateError('offline');
      }
      final current = books[userId];
      if (current?.writeId == writeId) {
        if (jsonEncode(current!.book.toJson()) != jsonEncode(book.toJson())) {
          throw StateError('write id reused');
        }
        return current.revision;
      }
      if ((current?.revision ?? 0) != expectedRevision) {
        throw PracticeRevisionConflict();
      }
      if (current != null) history.add(current);
      final revision = expectedRevision + 1;
      books[userId] =
          RemotePracticeBook(book: book, revision: revision, writeId: writeId);
      if (loseReply) {
        loseReply = false;
        throw StateError('reply lost after commit');
      }
      return revision;
    } finally {
      active -= 1;
    }
  }
}

CurriculumCatalog _catalog() {
  Map<String, dynamic> read(String file) =>
      jsonDecode(File('assets/curriculum/$file').readAsStringSync())
          as Map<String, dynamic>;
  return CurriculumCatalog.fromDecoded(
      levels: read('levels.json'),
      sourceMap: read('source-map.json'),
      audioManifest: read('audio-manifest.json'),
      exercises: read('exercises.json'),
      competencies: read('competencies.json'),
      lessons: read('lessons.json'));
}
