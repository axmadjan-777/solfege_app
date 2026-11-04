import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../curriculum/models/curriculum_config.dart';
import 'clock.dart';
import 'practice_book_sync.dart';
import 'progress_store.dart';

enum AccountSyncState {
  local,
  syncing,
  synced,
  error,
  conflict,
  legacyRemote,
  closed
}

/// One immutable owner. Disk and network have separate serialized queues:
/// an offline server cannot block subsequent local evidence from being saved.
class AccountProgressStore extends ChangeNotifier implements ProgressStore {
  AccountProgressStore({
    required this.preferences,
    required this.userId,
    required Clock clock,
    required MasteryRules rules,
    required this.currentUserId,
    this.remote,
    String Function()? newWriteId,
    Future<bool> Function(String key, String value)? writeString,
    Future<int> Function(Future<int> request, Duration timeout)? waitForSave,
    this.requestTimeout = const Duration(seconds: 15),
  })  : _newWriteId = newWriteId ?? _uuid,
        _writeString = writeString ?? preferences.setString,
        _waitForSave = waitForSave ?? _defaultWaitForSave {
    if (currentUserId() != userId) throw PracticeAccountChanged();
    if (userId.isEmpty || userId == 'local') {
      throw ArgumentError.value(
          userId, 'userId', 'Authenticated owner required');
    }
    final raw = preferences.getString(storageKey);
    ProgressBook? initial;
    if (raw != null) {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      initial = ProgressBook.fromJson(
          Map<String, dynamic>.from(envelope['book'] as Map));
      if (envelope['user_id'] != userId || initial.userId != userId) {
        throw StateError('Stored progress belongs to a different account');
      }
      _revision = envelope['remote_revision'] as int?;
      _pendingWriteId = envelope['pending_write_id'] as String?;
    }
    _memory = MemoryProgressStore(
        clock: clock, rules: rules, userId: userId, book: initial);
    if (initial != null &&
        _hasData(initial) &&
        _revision == null &&
        _pendingWriteId == null) {
      _pendingWriteId = _newWriteId();
    }
    _readLegacy();
  }

  static const legacyKey = 'practice_progress_v1';
  static const legacyClaimKey = 'practice_progress_v1_claimed_by';
  static String keyFor(String userId) =>
      'practice_progress_v2:${Uri.encodeComponent(userId)}';
  static final Map<String, Future<void>> _accountWrites = {};
  static final Map<String, Future<void>> _backupWrites = {};
  static Future<void> pendingLocalWrites(String userId) async {
    await _accountWrites[keyFor(userId)];
  }

  final SharedPreferences preferences;
  final String userId;
  final String? Function() currentUserId;
  final PracticeBookRemote? remote;
  final Duration requestTimeout;
  final String Function() _newWriteId;
  final Future<bool> Function(String key, String value) _writeString;
  final Future<int> Function(Future<int> request, Duration timeout)
      _waitForSave;
  late final MemoryProgressStore _memory;
  Future<void> _localTail = Future.value();
  Future<void>? _worker;
  Object? _localError;
  bool _closed = false;
  bool _disposed = false;
  bool _initialized = false;
  bool _choiceInFlight = false;
  int? _revision;
  String? _pendingWriteId;
  ProgressBook? _legacy;
  AccountSyncState state = AccountSyncState.local;
  String? message;

  String get storageKey => keyFor(userId);
  bool get isActive => !_closed && currentUserId() == userId;
  bool get hasPendingChanges => _pendingWriteId != null;
  bool get hasLegacy {
    final claim = preferences.getString(legacyClaimKey);
    return _legacy != null && (claim == null || claim == userId);
  }

  bool get hasBackup => preferences.containsKey('$storageKey:backups');
  int? get remoteRevision => _revision;
  @override
  ProgressBook get book => _memory.book;

  void _readLegacy() {
    final claim = preferences.getString(legacyClaimKey);
    if (claim != null && claim != userId) return;
    if (preferences.getBool('$storageKey:legacy_dismissed') == true) return;
    final raw = preferences.getString(legacyKey);
    if (raw == null) return;
    try {
      final old =
          ProgressBook.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (_hasData(old)) _legacy = old;
    } catch (_) {
      // Retain malformed legacy data unchanged; never silently reinterpret it.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _checkActive() {
    if (!isActive) throw PracticeAccountChanged();
  }

  Future<void> _persist() {
    final encoded = jsonEncode({
      'user_id': userId,
      'book': book.toJson(),
      'remote_revision': _revision,
      'pending_write_id': _pendingWriteId
    });
    final operation =
        (_accountWrites[storageKey] ?? _localTail).then((_) async {
      if (!await _writeString(storageKey, encoded)) {
        throw StateError('Local progress could not be saved');
      }
      _localError = null;
    });
    // Attach an error handler immediately, including for void UI callbacks.
    _localTail =
        operation.then<void>((_) {}, onError: (Object error, StackTrace stack) {
      _localError = error;
      state = AccountSyncState.error;
      message =
          'Не удалось сохранить прогресс на устройстве. Повторите сохранение.';
      _notify();
    });
    _accountWrites[storageKey] = _localTail;
    return operation;
  }

  Future<void> flushLocal() async {
    while (true) {
      final tail = _localTail;
      await tail;
      if (identical(tail, _localTail)) break;
    }
    if (_localError != null) throw _localError!;
  }

  void _changed() {
    _pendingWriteId = _newWriteId();
    _persist();
    _notify();
    startSync();
  }

  @override
  CompetencySnapshot snapshot(String id) => _memory.snapshot(id);
  @override
  void recordSession(SessionDraft session) {
    if (!isActive) return;
    _memory.recordSession(session);
    _changed();
  }

  @override
  void scheduleNextDayReturn(String tag) => scheduleReturnInDays(tag, 1);
  @override
  void scheduleReturnInDays(String tag, int days) {
    if (!isActive) return;
    _memory.scheduleReturnInDays(tag, days);
    _changed();
  }

  @override
  List<String> openErrorTags() => _memory.openErrorTags();

  @override
  void markStagePassed(String setId, int stage) {
    if (!isActive) return;
    _memory.markStagePassed(setId, stage);
    _changed();
  }

  /// One managed save at a time. A timed-out HTTP request can still complete;
  /// server CAS and write IDs also protect retries against that late request.
  void startSync() {
    if (!isActive ||
        remote == null ||
        _worker != null ||
        state == AccountSyncState.error ||
        state == AccountSyncState.conflict ||
        state == AccountSyncState.legacyRemote) {
      return;
    }
    _worker = Future<void>.microtask(_run).whenComplete(() {
      _worker = null;
      if (isActive && hasPendingChanges && state == AccountSyncState.synced) {
        startSync();
      }
    });
  }

  Future<void> waitForSync() async {
    await _worker;
  }

  Future<void> _run() async {
    try {
      state = AccountSyncState.syncing;
      message = null;
      _notify();
      await flushLocal();
      _checkActive();
      if (!_initialized) await _loadRemote();
      while (isActive &&
          _pendingWriteId != null &&
          state != AccountSyncState.conflict &&
          state != AccountSyncState.legacyRemote) {
        await flushLocal();
        _checkActive();
        final writeId = _pendingWriteId!;
        final snapshot = ProgressBook.fromJson(
            jsonDecode(jsonEncode(book.toJson())) as Map<String, dynamic>);
        final revision = await _waitForSave(
            remote!.push(
                userId: userId,
                book: snapshot,
                expectedRevision: _revision!,
                writeId: writeId),
            requestTimeout);
        _checkActive();
        _revision = revision;
        if (_pendingWriteId == writeId) _pendingWriteId = null;
        await _persist();
      }
      if (isActive &&
          state != AccountSyncState.conflict &&
          state != AccountSyncState.legacyRemote) {
        state = AccountSyncState.synced;
      }
    } on PracticeAccountChanged {
      close(); // Pending evidence remains in its original account's local key.
    } on PracticeRevisionConflict {
      try {
        await remote!.pull(userId).timeout(requestTimeout);
        _checkActive();
        state = AccountSyncState.conflict;
        message =
            'В облаке есть другая версия. Обе копии сохранены; выберите нужную.';
      } on PracticeAccountChanged {
        close();
      } catch (_) {
        _syncError();
      }
    } catch (_) {
      _syncError();
    }
    _notify();
  }

  Future<void> _loadRemote() async {
    final latest = await remote!.pull(userId).timeout(requestTimeout);
    _checkActive();
    _initialized = true;
    if (latest == null) {
      _revision = 0;
    } else if (latest.book.userId != userId) {
      _revision = latest.revision;
      state = AccountSyncState.legacyRemote;
      message =
          'Старый облачный прогресс не привязан к владельцу. Выберите, импортировать ли его.';
    } else if (_pendingWriteId == latest.writeId &&
        _sameJson(book.toJson(), latest.book.toJson())) {
      _revision = latest.revision;
      _pendingWriteId = null;
    } else if (_pendingWriteId != null &&
        ((_revision == null && _hasData(latest.book)) ||
            (_revision != null && _revision != latest.revision))) {
      state = AccountSyncState.conflict;
      message =
          'В облаке есть другая версия. Обе копии сохранены; выберите нужную.';
    } else {
      _revision = latest.revision;
      if (_pendingWriteId == null) _memory.book = latest.book;
    }
    await _persist();
  }

  void _syncError() {
    if (!isActive) {
      close();
      return;
    }
    if (_localError != null) return;
    state = AccountSyncState.error;
    message =
        'Прогресс сохранён на устройстве. Облако недоступно; повторите синхронизацию.';
  }

  Future<void> _exclusiveChoice(Future<void> Function() action) async {
    _checkActive();
    if (_choiceInFlight) {
      throw StateError('Another progress choice is still being saved');
    }
    _choiceInFlight = true;
    try {
      await action();
    } finally {
      _choiceInFlight = false;
    }
  }

  void _checkReplacement(ProgressBook expected) {
    _checkActive();
    if (!identical(book, expected)) {
      throw StateError(
          'New evidence arrived while the progress choice was being saved');
    }
  }

  Future<void> retrySync() => _exclusiveChoice(_retrySync);
  Future<void> _retrySync() async {
    _checkActive();
    await _worker;
    await _persist();
    _initialized = false;
    state = AccountSyncState.local;
    startSync();
    await waitForSync();
  }

  Future<void> _backup(ProgressBook previous) async {
    final operation =
        (_backupWrites[storageKey] ?? Future<void>.value()).then((_) async {
      final raw = preferences.getString('$storageKey:backups');
      final copies =
          raw == null ? <dynamic>[] : jsonDecode(raw) as List<dynamic>;
      copies.add(previous.toJson());
      if (!await _writeString('$storageKey:backups', jsonEncode(copies))) {
        throw StateError('Cannot retain the previous copy');
      }
    });
    _backupWrites[storageKey] =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    await operation;
    _checkActive();
  }

  /// Only called after an explicit import confirmation; the shared source stays.
  Future<void> importLegacy() => _exclusiveChoice(_importLegacy);
  Future<void> _importLegacy() async {
    _checkActive();
    await _worker;
    _checkActive();
    final old = _legacy;
    if (old == null) return;
    final claim = preferences.getString(legacyClaimKey);
    if (claim != null && claim != userId) throw PracticeAccountChanged();
    if (!await _writeString(legacyClaimKey, userId)) {
      throw StateError('Cannot retain the legacy ownership choice');
    }
    _checkActive();
    final expected = book;
    if (_hasData(expected)) await _backup(expected);
    _checkReplacement(expected);
    _memory.book = _ownedCopy(old);
    _changed();
    await flushLocal();
    if (!await preferences.setBool('$storageKey:legacy_dismissed', true)) {
      throw StateError('Cannot retain the completed import choice');
    }
    _checkActive();
    _legacy = null;
    _notify();
  }

  Future<void> dismissLegacy() => _exclusiveChoice(_dismissLegacy);
  Future<void> _dismissLegacy() async {
    _checkActive();
    if (!await preferences.setBool('$storageKey:legacy_dismissed', true)) {
      throw StateError('Cannot retain the legacy choice');
    }
    _checkActive();
    _legacy = null;
    _notify();
  }

  /// Explicit resolution; retains the unchosen local copy and the RPC archives
  /// superseded server versions transactionally. A fresh CAS still protects races.
  Future<void> resolveConflict({required bool useRemote}) =>
      _exclusiveChoice(() => _resolveConflict(useRemote: useRemote));
  Future<void> _resolveConflict({required bool useRemote}) async {
    _checkActive();
    await _worker;
    final latest = await remote!.pull(userId).timeout(requestTimeout);
    _checkActive();
    if (latest == null) {
      _revision = 0;
    } else {
      final expected = book;
      await _backup(useRemote ? expected : latest.book);
      if (useRemote) _checkReplacement(expected);
      _revision = latest.revision;
      if (useRemote) _memory.book = _ownedCopy(latest.book);
    }
    _initialized = true;
    _pendingWriteId = _newWriteId();
    state = AccountSyncState.local;
    message = null;
    await _persist();
    _notify();
    startSync();
    await waitForSync();
  }

  Future<void> restoreBackup() => _exclusiveChoice(_restoreBackup);
  Future<void> _restoreBackup() async {
    _checkActive();
    await _worker;
    final raw = preferences.getString('$storageKey:backups');
    if (raw == null) return;
    final copies = jsonDecode(raw) as List<dynamic>;
    if (copies.isEmpty) return;
    final restored =
        ProgressBook.fromJson(Map<String, dynamic>.from(copies.last as Map));
    final expected = book;
    await _backup(expected);
    _checkReplacement(expected);
    _memory.book = _ownedCopy(restored);
    _changed();
    await flushLocal();
  }

  ProgressBook _ownedCopy(ProgressBook source) =>
      ProgressBook.fromJson({...source.toJson(), 'user_id': userId});
  void close() {
    _closed = true;
    state = AccountSyncState.closed;
  }

  @override
  void dispose() {
    close();
    _disposed = true;
    super.dispose();
  }
}

bool _hasData(ProgressBook book) {
  final passedStages = book.toJson()['passed_stages'];
  return book.attempts.isNotEmpty ||
      book.competencies.isNotEmpty ||
      book.returns.isNotEmpty ||
      (passedStages is Map && passedStages.isNotEmpty) ||
      (passedStages is List && passedStages.isNotEmpty);
}

Future<int> _defaultWaitForSave(Future<int> request, Duration timeout) =>
    request.timeout(timeout);
bool _sameJson(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _sameJson(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => _sameJson(a[i], b[i]));
  }
  return a == b;
}

String _uuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
