import 'package:supabase_flutter/supabase_flutter.dart';

import 'progress_store.dart';

class PracticeAccountChanged implements Exception {}

class PracticeRevisionConflict implements Exception {}

class RemotePracticeBook {
  const RemotePracticeBook(
      {required this.book, required this.revision, this.writeId});
  final ProgressBook book;
  final int revision;
  final String? writeId;
}

abstract interface class PracticeBookRemote {
  Future<RemotePracticeBook?> pull(String userId);
  Future<int> push(
      {required String userId,
      required ProgressBook book,
      required int expectedRevision,
      required String writeId});
}

/// Requests always carry the binding's fixed owner, never a newly signed-in user.
class PracticeBookSync implements PracticeBookRemote {
  const PracticeBookSync(this.client);
  final SupabaseClient client;

  void _checkOwner(String userId) {
    if (client.auth.currentUser?.id != userId) throw PracticeAccountChanged();
  }

  String _authorization(String userId) {
    _checkOwner(userId);
    final session = client.auth.currentSession;
    if (session == null ||
        session.user.id != userId ||
        session.accessToken.isEmpty) {
      throw PracticeAccountChanged();
    }
    return 'Bearer ${session.accessToken}';
  }

  @override
  Future<RemotePracticeBook?> pull(String userId) async {
    final authorization = _authorization(userId);
    final row = await client
        .from('practice_books')
        .select('book, revision, last_write_id')
        .eq('user_id', userId)
        .maybeSingle()
        .setHeader('Authorization', authorization);
    _checkOwner(userId);
    if (row == null) return null;
    return RemotePracticeBook(
      book:
          ProgressBook.fromJson(Map<String, dynamic>.from(row['book'] as Map)),
      revision: (row['revision'] as num).toInt(),
      writeId: row['last_write_id'] as String?,
    );
  }

  @override
  Future<int> push(
      {required String userId,
      required ProgressBook book,
      required int expectedRevision,
      required String writeId}) async {
    final authorization = _authorization(userId);
    if (book.userId != userId) throw PracticeAccountChanged();
    try {
      final revision = await client
          .rpc('save_practice_book', params: {
            'p_user_id': userId,
            'p_expected_revision': expectedRevision,
            'p_write_id': writeId,
            'p_book': book.toJson(),
          })
          .setHeader('Authorization', authorization)
          .retry(enabled: false);
      _checkOwner(userId);
      return (revision as num).toInt();
    } on PostgrestException catch (error) {
      if (error.code == '40001') throw PracticeRevisionConflict();
      rethrow;
    }
  }
}
