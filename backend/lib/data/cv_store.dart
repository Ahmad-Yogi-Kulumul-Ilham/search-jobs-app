import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../ai/cv_reviewer.dart';
import '../models/cv.dart';
import '../util/docx_text.dart';

/// A stored review of one CV against one job.
class StoredReview {
  const StoredReview({
    required this.jobId,
    required this.cvId,
    required this.review,
    required this.model,
    required this.costUsd,
    required this.createdAt,
  });

  final String jobId;
  final int cvId;
  final CvReview review;
  final String model;
  final double costUsd;
  final DateTime createdAt;
}

/// The user's CV versions, their reviews, and saved answers.
class CvStore {
  CvStore(this._db);

  final Database _db;

  List<Cv> all() => [
    for (final row in _db.select('SELECT * FROM cvs ORDER BY created_at DESC'))
      _cvFromRow(row),
  ];

  Cv? find(int id) {
    final rows = _db.select('SELECT * FROM cvs WHERE id = ?', [id]);
    return rows.isEmpty ? null : _cvFromRow(rows.first);
  }

  /// Stores an uploaded file. Throws [FormatException] for an unsupported
  /// format or a file that cannot be read.
  Cv add({
    required String name,
    required String fileName,
    required Uint8List bytes,
    required DateTime now,
  }) {
    final format = CvFormat.fromFileName(fileName);
    if (format == null) {
      throw const FormatException(
        'Format tidak didukung. Pakai PDF atau DOCX.',
      );
    }
    if (format == CvFormat.pdf &&
        (bytes.length < 5 ||
            utf8.decode(bytes.sublist(0, 5), allowMalformed: true) !=
                '%PDF-')) {
      throw const FormatException('File ini bukan PDF yang valid.');
    }
    final text = switch (format) {
      CvFormat.pdf => '',
      CvFormat.docx => docxText(bytes),
      CvFormat.text => utf8.decode(bytes, allowMalformed: true).trim(),
    };
    if (format != CvFormat.pdf && text.isEmpty) {
      throw const FormatException('File ini kosong.');
    }
    _db.execute(
      '''
      INSERT INTO cvs (name, file_name, format, bytes, text, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [
        name.trim(),
        fileName,
        format.name,
        bytes,
        text,
        now.millisecondsSinceEpoch,
      ],
    );
    return find(_db.lastInsertRowId)!;
  }

  void rename(int id, String name) =>
      _db.execute('UPDATE cvs SET name = ? WHERE id = ?', [name.trim(), id]);

  /// Removes a CV together with its reviews.
  void delete(int id) {
    _db.execute('DELETE FROM reviews WHERE cv_id = ?', [id]);
    _db.execute('DELETE FROM cvs WHERE id = ?', [id]);
  }

  void saveReview(StoredReview stored) => _db.execute(
    '''
    INSERT INTO reviews (job_id, cv_id, score, result, model, cost_usd, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT (job_id, cv_id) DO UPDATE SET
      score = excluded.score,
      result = excluded.result,
      model = excluded.model,
      cost_usd = excluded.cost_usd,
      created_at = excluded.created_at
    ''',
    [
      stored.jobId,
      stored.cvId,
      stored.review.score,
      jsonEncode(stored.review.toJson()),
      stored.model,
      stored.costUsd,
      stored.createdAt.millisecondsSinceEpoch,
    ],
  );

  /// Reviews of [jobId], one per CV that was reviewed, newest first.
  List<StoredReview> reviewsFor(String jobId) => [
    for (final row in _db.select(
      'SELECT * FROM reviews WHERE job_id = ? ORDER BY created_at DESC',
      [jobId],
    ))
      StoredReview(
        jobId: row['job_id'] as String,
        cvId: row['cv_id'] as int,
        review: CvReview.fromJson(
          jsonDecode(row['result'] as String) as Map<String, Object?>,
        ),
        model: row['model'] as String,
        costUsd: (row['cost_usd'] as num).toDouble(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at'] as int,
        ),
      ),
  ];

  /// Total spent on AI requests so far, in US dollars.
  double totalCostUsd() =>
      (_db
                  .select(
                    'SELECT COALESCE(SUM(cost_usd), 0) AS total FROM ai_spend',
                  )
                  .first['total']
              as num)
          .toDouble();

  /// Records the cost of any AI request, reviews and drafts alike.
  void recordSpend(double costUsd, DateTime now) => _db.execute(
    'INSERT INTO ai_spend (cost_usd, created_at) VALUES (?, ?)',
    [costUsd, now.millisecondsSinceEpoch],
  );

  List<SavedAnswer> answers() => [
    for (final row in _db.select('SELECT * FROM answers ORDER BY question'))
      SavedAnswer(
        id: row['id'] as int,
        question: row['question'] as String,
        answer: row['answer'] as String,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['updated_at'] as int,
        ),
      ),
  ];

  /// Adds an answer, or replaces the one with [id].
  void saveAnswer({
    int? id,
    required String question,
    required String answer,
    required DateTime now,
  }) {
    if (id == null) {
      _db.execute(
        'INSERT INTO answers (question, answer, updated_at) VALUES (?, ?, ?)',
        [question.trim(), answer.trim(), now.millisecondsSinceEpoch],
      );
    } else {
      _db.execute(
        'UPDATE answers SET question = ?, answer = ?, updated_at = ? WHERE id = ?',
        [question.trim(), answer.trim(), now.millisecondsSinceEpoch, id],
      );
    }
  }

  void deleteAnswer(int id) =>
      _db.execute('DELETE FROM answers WHERE id = ?', [id]);
}

Cv _cvFromRow(Row row) => Cv(
  id: row['id'] as int,
  name: row['name'] as String,
  fileName: row['file_name'] as String,
  format:
      CvFormat.values.where((f) => f.name == row['format']).firstOrNull ??
      CvFormat.text,
  bytes: row['bytes'] as Uint8List,
  text: row['text'] as String,
  createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
);
