import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/qbank_repository.dart';
import '../../../shared/models/qbank_models.dart';

final qbankRepositoryProvider = Provider<QBankRepository>((ref) {
  return QBankRepository();
});

final qbankSessionsProvider = FutureProvider<List<QbankSession>>((ref) async {
  final repo = ref.watch(qbankRepositoryProvider);
  return repo.getSessions();
});

final qbankSubjectsProvider =
    FutureProvider.family<List<QbankSubject>, String>((ref, sessionId) async {
  final repo = ref.watch(qbankRepositoryProvider);
  return repo.getSubjects(sessionId);
});

final qbankChaptersProvider =
    FutureProvider.family<List<QbankChapter>, String>((ref, subjectId) async {
  final repo = ref.watch(qbankRepositoryProvider);
  return repo.getChapters(subjectId);
});

final qbankChapterStatsProvider = FutureProvider.family<List<QbankChapterStats>, String>(
  (ref, subjectId) async {
    final repo = ref.watch(qbankRepositoryProvider);
    return repo.getChapterStatsForSubject(subjectId);
  },
);

class QbankQuestionQuery {
  const QbankQuestionQuery({
    required this.chapterId,
    this.difficulty,
    this.source,
    this.boardYear,
    this.limit,
    this.offset,
  });

  final String chapterId;
  final String? difficulty;
  final String? source;
  final int? boardYear;
  final int? limit;
  final int? offset;
}

final qbankMcqQuestionsProvider =
    FutureProvider.family<List<QbankMcq>, QbankQuestionQuery>((ref, query) async {
  final repo = ref.watch(qbankRepositoryProvider);
  return repo.getMcqQuestions(
    chapterId: query.chapterId,
    difficulty: query.difficulty,
    source: query.source,
    boardYear: query.boardYear,
    limit: query.limit,
    offset: query.offset,
  );
});

final qbankCqQuestionsProvider =
    FutureProvider.family<List<QbankCq>, QbankQuestionQuery>((ref, query) async {
  final repo = ref.watch(qbankRepositoryProvider);
  return repo.getCqQuestions(
    chapterId: query.chapterId,
    difficulty: query.difficulty,
    source: query.source,
    boardYear: query.boardYear,
    limit: query.limit,
    offset: query.offset,
  );
});

final qbankBookmarksProvider =
    FutureProvider.family<List<QbankBookmarkItem>, String>((ref, studentId) async {
  final repo = ref.watch(qbankRepositoryProvider);
  return repo.getBookmarks(studentId);
});
