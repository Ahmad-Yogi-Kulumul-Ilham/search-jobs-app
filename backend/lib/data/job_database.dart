import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../models/job.dart';

/// Local SQLite store for fetched jobs, so the app opens instantly and works
/// offline between refreshes.
class JobDatabase {
  JobDatabase._(this._db) {
    _migrate();
  }

  factory JobDatabase.open(String path) => JobDatabase._(sqlite3.open(path));

  factory JobDatabase.inMemory() => JobDatabase._(sqlite3.openInMemory());

  /// Jobs a source no longer lists are kept this long before being removed.
  static const retention = Duration(days: 30);

  final Database _db;

  void _migrate() {
    final version = _db.select('PRAGMA user_version').first.values.first as int;
    if (version < 1) {
      _db.execute('''
        CREATE TABLE jobs (
          id TEXT PRIMARY KEY,
          source_id TEXT NOT NULL,
          title TEXT NOT NULL,
          company TEXT NOT NULL,
          url TEXT NOT NULL,
          location TEXT NOT NULL,
          category TEXT NOT NULL,
          tags TEXT NOT NULL,
          job_type TEXT NOT NULL,
          salary TEXT NOT NULL,
          description_html TEXT NOT NULL,
          published_at INTEGER,
          first_seen_at INTEGER NOT NULL,
          last_seen_at INTEGER NOT NULL
        );
        CREATE INDEX jobs_by_published ON jobs (published_at DESC);
        CREATE TABLE source_state (
          source_id TEXT PRIMARY KEY,
          last_fetched_at INTEGER NOT NULL
        );
        PRAGMA user_version = 1;
      ''');
    }
  }

  /// Stores one source's latest fetch: inserts new jobs, updates known ones,
  /// drops jobs the source stopped listing [retention] ago, and records the
  /// fetch time.
  void saveFetch(String sourceId, List<Job> jobs, DateTime fetchedAt) {
    final now = fetchedAt.millisecondsSinceEpoch;
    _db.execute('BEGIN');
    try {
      for (final job in jobs) {
        _db.execute(
          '''
          INSERT INTO jobs (
            id, source_id, title, company, url, location, category, tags,
            job_type, salary, description_html, published_at,
            first_seen_at, last_seen_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT (id) DO UPDATE SET
            title = excluded.title,
            company = excluded.company,
            url = excluded.url,
            location = excluded.location,
            category = excluded.category,
            tags = excluded.tags,
            job_type = excluded.job_type,
            salary = excluded.salary,
            description_html = excluded.description_html,
            published_at = excluded.published_at,
            last_seen_at = excluded.last_seen_at
          ''',
          [
            job.id,
            sourceId,
            job.title,
            job.company,
            job.url,
            job.location,
            job.category,
            jsonEncode(job.tags),
            job.jobType,
            job.salary,
            job.descriptionHtml,
            job.publishedAt?.millisecondsSinceEpoch,
            now,
            now,
          ],
        );
      }
      _db.execute(
        'DELETE FROM jobs WHERE source_id = ? AND last_seen_at < ?',
        [sourceId, now - retention.inMilliseconds],
      );
      _db.execute(
        '''
        INSERT INTO source_state (source_id, last_fetched_at) VALUES (?, ?)
        ON CONFLICT (source_id) DO UPDATE SET
          last_fetched_at = excluded.last_fetched_at
        ''',
        [sourceId, now],
      );
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  DateTime? lastFetchedAt(String sourceId) {
    final rows = _db.select(
      'SELECT last_fetched_at FROM source_state WHERE source_id = ?',
      [sourceId],
    );
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      rows.first['last_fetched_at'] as int,
    );
  }

  /// The most recent fetch of any source, or null before the first one.
  DateTime? latestFetch() {
    final value = _db
        .select('SELECT MAX(last_fetched_at) AS latest FROM source_state')
        .first['latest'];
    return value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
  }

  /// Jobs matching every word of [query], newest first, without their
  /// descriptions (see [descriptionOf]).
  List<Job> search({
    String query = '',
    Set<String> excludedSources = const {},
    int limit = 500,
  }) {
    final conditions = <String>[];
    final args = <Object?>[];
    final words = query.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    for (final word in words) {
      final escaped = word.replaceAllMapped(
        RegExp(r'[\\%_]'),
        (match) => '\\${match[0]}',
      );
      conditions.add(
        '(${_searchedColumns.map((c) => "$c LIKE ? ESCAPE '\\'").join(' OR ')})',
      );
      args.addAll(List.filled(_searchedColumns.length, '%$escaped%'));
    }
    if (excludedSources.isNotEmpty) {
      final marks = List.filled(excludedSources.length, '?').join(', ');
      conditions.add('source_id NOT IN ($marks)');
      args.addAll(excludedSources);
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = _db.select(
      '''
      SELECT id, source_id, title, company, url, location, category, tags,
             job_type, salary, published_at
      FROM jobs $where
      ORDER BY published_at IS NULL, published_at DESC, id
      LIMIT ?
      ''',
      [...args, limit],
    );
    return [for (final row in rows) _jobFromRow(row)];
  }

  String descriptionOf(String jobId) {
    final rows = _db.select(
      'SELECT description_html FROM jobs WHERE id = ?',
      [jobId],
    );
    return rows.isEmpty ? '' : rows.first['description_html'] as String;
  }

  void close() => _db.close();
}

const _searchedColumns = ['title', 'company', 'location', 'category', 'tags'];

Job _jobFromRow(Row row) {
  final publishedAt = row['published_at'] as int?;
  return Job(
    id: row['id'] as String,
    sourceId: row['source_id'] as String,
    title: row['title'] as String,
    company: row['company'] as String,
    url: row['url'] as String,
    location: row['location'] as String,
    category: row['category'] as String,
    tags: (jsonDecode(row['tags'] as String) as List).cast<String>(),
    jobType: row['job_type'] as String,
    salary: row['salary'] as String,
    publishedAt: publishedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(publishedAt),
  );
}
