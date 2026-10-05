import 'package:supabase_flutter/supabase_flutter.dart';

import 'practice_book_rows.dart';
import 'progress_store.dart';

/// Пишет книгу в `practice_books` и разложенные таблицы.
/// Без сессии ничего не делает.
class PracticeBookSync {
  const PracticeBookSync(this.client);

  final SupabaseClient client;

  String? get _userId => client.auth.currentUser?.id;

  Future<ProgressBook?> pull() async {
    final userId = _userId;
    if (userId == null) return null;
    final row = await client
        .from('practice_books')
        .select('book')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    final book = row['book'];
    if (book is! Map) return null;
    return ProgressBook.fromJson(Map<String, dynamic>.from(book));
  }

  Future<void> push(ProgressBook book) async {
    final userId = _userId;
    if (userId == null) return;
    final at = DateTime.now().toUtc();
    await client.from('practice_books').upsert(
          practiceBookPayload(userId: userId, book: book, at: at),
        );
    await client.from('practice_attempts').delete().eq('user_id', userId);
    final attempts = practiceAttemptRows(userId: userId, book: book);
    if (attempts.isNotEmpty) {
      await client.from('practice_attempts').insert(attempts);
    }
    await client.from('practice_competencies').delete().eq('user_id', userId);
    final competencies =
        practiceCompetencyRows(userId: userId, book: book, at: at);
    if (competencies.isNotEmpty) {
      await client.from('practice_competencies').insert(competencies);
    }
    await client.from('practice_returns').delete().eq('user_id', userId);
    final returns = practiceReturnRows(userId: userId, book: book);
    if (returns.isNotEmpty) {
      await client.from('practice_returns').insert(returns);
    }
  }
}
