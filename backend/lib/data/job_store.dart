import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../models/application.dart';
import '../models/job.dart';
import '../models/salary.dart';
import '../util/format.dart';
import '../util/region.dart';
import '../util/scam_check.dart';

/// What the job list is narrowed to.
class JobFilter {
  const JobFilter({
    this.query = '',
    this.excludedSources = const {},
    this.openToIndonesiaOnly = false,
    this.jobTypes = const {},
    this.withSalaryOnly = false,
  });

  /// Words that must all appear in the title, company, location, category,
  /// or tags.
  final String query;
  final Set<String> excludedSources;

  /// Keep only jobs whose location is [RegionFit.open].
  final bool openToIndonesiaOnly;

  /// Job type labels to keep; empty keeps every type.
  final Set<String> jobTypes;
  final bool withSalaryOnly;

  /// How many filters are on, not counting the search words.
  int get activeCount =>
      (openToIndonesiaOnly ? 1 : 0) +
      (jobTypes.isEmpty ? 0 : 1) +
      (withSalaryOnly ? 1 : 0) +
      (excludedSources.isEmpty ? 0 : 1);

  JobFilter copyWith({
    String? query,
    Set<String>? excludedSources,
    bool? openToIndonesiaOnly,
    Set<String>? jobTypes,
    bool? withSalaryOnly,
  }) => JobFilter(
    query: query ?? this.query,
    excludedSources: excludedSources ?? this.excludedSources,
    openToIndonesiaOnly: openToIndonesiaOnly ?? this.openToIndonesiaOnly,
    jobTypes: jobTypes ?? this.jobTypes,
    withSalaryOnly: withSalaryOnly ?? this.withSalaryOnly,
  );

  factory JobFilter.fromJson(Map<String, Object?> json) {
    Set<String> strings(Object? value) => {
      for (final item in value is List ? value : const []) '$item',
    };
    return JobFilter(
      query: json['query'] as String? ?? '',
      excludedSources: strings(json['excludedSources']),
      openToIndonesiaOnly: json['openToIndonesiaOnly'] == true,
      jobTypes: strings(json['jobTypes']),
      withSalaryOnly: json['withSalaryOnly'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'query': query,
    'excludedSources': excludedSources.toList(),
    'openToIndonesiaOnly': openToIndonesiaOnly,
    'jobTypes': jobTypes.toList(),
    'withSalaryOnly': withSalaryOnly,
  };

  /// A short Indonesian summary such as `"flutter" · bisa dari Indonesia`.
  String describe() => [
    if (query.trim().isNotEmpty) '"${query.trim()}"',
    if (openToIndonesiaOnly) 'bisa dari Indonesia',
    if (withSalaryOnly) 'ada gaji',
    if (jobTypes.isNotEmpty) jobTypes.join('/'),
    if (excludedSources.isNotEmpty)
      '${excludedSources.length} sumber dimatikan',
  ].join(' · ');
}

/// Fetched jobs, plus the user's choices about which ones to keep seeing.
class JobStore {
  JobStore(this._db);

  /// Jobs a source no longer lists are kept this long before being removed.
  static const retention = Duration(days: 30);

  final Database _db;

  /// Stores one source's latest fetch: inserts new jobs, updates known ones,
  /// drops untracked jobs the source stopped listing [retention] ago, and
  /// records the fetch time. Returns the ids of jobs not seen before.
  List<String> saveFetch(String sourceId, List<Job> jobs, DateTime fetchedAt) {
    final now = fetchedAt.millisecondsSinceEpoch;
    final known = {
      for (final row in _db.select('SELECT id FROM jobs WHERE source_id = ?', [
        sourceId,
      ]))
        row['id'] as String,
    };
    _db.execute('BEGIN');
    try {
      for (final job in jobs) {
        final salary = job.salaryRange;
        _db.execute(
          '''
          INSERT INTO jobs (
            id, source_id, title, company, url, location, category, tags,
            job_type, salary, salary_min, salary_max, salary_currency,
            salary_period, region_fit, scam_flags, description_html,
            published_at, first_seen_at, last_seen_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT (id) DO UPDATE SET
            title = excluded.title,
            company = excluded.company,
            url = excluded.url,
            location = excluded.location,
            category = excluded.category,
            tags = excluded.tags,
            job_type = excluded.job_type,
            salary = excluded.salary,
            salary_min = excluded.salary_min,
            salary_max = excluded.salary_max,
            salary_currency = excluded.salary_currency,
            salary_period = excluded.salary_period,
            region_fit = excluded.region_fit,
            scam_flags = excluded.scam_flags,
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
            salary?.min,
            salary?.max,
            salary?.currency,
            salary?.period?.name,
            job.regionFit.name,
            jsonEncode(warningsFor(job)),
            job.descriptionHtml,
            job.publishedAt?.millisecondsSinceEpoch,
            now,
            now,
          ],
        );
      }
      _db.execute(
        '''
        DELETE FROM jobs
        WHERE source_id = ? AND last_seen_at < ?
          AND id NOT IN (SELECT job_id FROM applications)
        ''',
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
    return [
      for (final job in jobs)
        if (!known.contains(job.id)) job.id,
    ];
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

  /// Removes a source's jobs and fetch record, keeping tracked jobs.
  void forgetSource(String sourceId) {
    _db.execute(
      '''
      DELETE FROM jobs
      WHERE source_id = ? AND id NOT IN (SELECT job_id FROM applications)
      ''',
      [sourceId],
    );
    _db.execute('DELETE FROM source_state WHERE source_id = ?', [sourceId]);
  }

  Map<String, int> countBySource() => {
    for (final row in _db.select(
      'SELECT source_id, COUNT(*) AS total FROM jobs GROUP BY source_id',
    ))
      row['source_id'] as String: row['total'] as int,
  };

  /// Jobs matching [filter], newest first, without their descriptions (see
  /// [descriptionOf]). Hidden jobs and blocked companies never appear.
  /// When [onlyIds] is given, only those jobs are considered.
  List<Job> search({
    JobFilter filter = const JobFilter(),
    Iterable<String>? onlyIds,
    int limit = 500,
  }) {
    final conditions = <String>[
      'j.hidden = 0',
      'lower(j.company) NOT IN (SELECT name FROM blocked_companies)',
    ];
    final args = <Object?>[];
    if (onlyIds != null) {
      final ids = onlyIds.toList();
      if (ids.isEmpty) return const [];
      conditions.add('j.id IN (SELECT value FROM json_each(?))');
      args.add(jsonEncode(ids));
    }
    final words = filter.query.trim().split(RegExp(r'\s+'));
    for (final word in words.where((word) => word.isNotEmpty)) {
      conditions.add(
        '(${_searchedColumns.map((c) => "j.$c LIKE ? ESCAPE '\\'").join(' OR ')})',
      );
      args.addAll(List.filled(_searchedColumns.length, _contains(word)));
    }
    if (filter.excludedSources.isNotEmpty) {
      final marks = List.filled(filter.excludedSources.length, '?').join(', ');
      conditions.add('j.source_id NOT IN ($marks)');
      args.addAll(filter.excludedSources);
    }
    if (filter.openToIndonesiaOnly) {
      conditions.add("j.region_fit = '${RegionFit.open.name}'");
    }
    if (filter.jobTypes.isNotEmpty) {
      final any = List.filled(
        filter.jobTypes.length,
        "j.job_type LIKE ? ESCAPE '\\'",
      ).join(' OR ');
      conditions.add('($any)');
      args.addAll(filter.jobTypes.map(_contains));
    }
    if (filter.withSalaryOnly) conditions.add("j.salary <> ''");
    final rows = _db.select(
      '''
      SELECT $_listColumns
      FROM jobs j LEFT JOIN applications a ON a.job_id = j.id
      WHERE ${conditions.join(' AND ')}
      ORDER BY j.published_at IS NULL, j.published_at DESC, j.id
      LIMIT ?
      ''',
      [...args, limit],
    );
    return [for (final row in rows) _jobFromRow(row)];
  }

  /// The stored job with [jobId], hidden or not, without its description.
  Job? find(String jobId) {
    final rows = _db.select(
      '''
      SELECT $_listColumns
      FROM jobs j LEFT JOIN applications a ON a.job_id = j.id
      WHERE j.id = ?
      ''',
      [jobId],
    );
    return rows.isEmpty ? null : _jobFromRow(rows.first);
  }

  String descriptionOf(String jobId) {
    final rows = _db.select('SELECT description_html FROM jobs WHERE id = ?', [
      jobId,
    ]);
    return rows.isEmpty ? '' : rows.first['description_html'] as String;
  }

  void setHidden(String jobId, bool hidden) => _db.execute(
    'UPDATE jobs SET hidden = ? WHERE id = ?',
    [hidden ? 1 : 0, jobId],
  );

  int hiddenCount() =>
      _db.select('SELECT COUNT(*) AS n FROM jobs WHERE hidden = 1').first['n']
          as int;

  void unhideAll() => _db.execute('UPDATE jobs SET hidden = 0');

  /// Company names are matched ignoring case.
  void blockCompany(String company) => _db.execute(
    'INSERT OR IGNORE INTO blocked_companies (name) VALUES (?)',
    [company.trim().toLowerCase()],
  );

  void unblockCompany(String company) => _db.execute(
    'DELETE FROM blocked_companies WHERE name = ?',
    [company.trim().toLowerCase()],
  );

  List<String> blockedCompanies() => [
    for (final row in _db.select(
      'SELECT name FROM blocked_companies ORDER BY name',
    ))
      row['name'] as String,
  ];
}

const _searchedColumns = ['title', 'company', 'location', 'category', 'tags'];

const _listColumns = '''
  j.id, j.source_id, j.title, j.company, j.url, j.location, j.category,
  j.tags, j.job_type, j.salary, j.salary_min, j.salary_max,
  j.salary_currency, j.salary_period, j.published_at, j.scam_flags,
  a.status AS tracked_status,
  (SELECT MAX(score) FROM reviews r WHERE r.job_id = j.id) AS match_score
''';

/// Scam warnings for a job about to be stored, read from its description.
List<String> warningsFor(Job job) => scamWarnings(
  title: job.title,
  company: job.company,
  descriptionText: plainText(job.descriptionHtml),
);

String _contains(String word) {
  final escaped = word.replaceAllMapped(
    RegExp(r'[\\%_]'),
    (match) => '\\${match[0]}',
  );
  return '%$escaped%';
}

Job _jobFromRow(Row row) {
  final publishedAt = row['published_at'] as int?;
  final period = row['salary_period'] as String?;
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
    salaryRange: SalaryRange.of(
      row['salary_min'] as double?,
      row['salary_max'] as double?,
      currency: row['salary_currency'] as String? ?? '',
      period: SalaryPeriod.values.where((p) => p.name == period).firstOrNull,
    ),
    publishedAt: publishedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(publishedAt),
    trackedStatus: ApplicationStatus.byName(row['tracked_status'] as String?),
    warnings: (jsonDecode(row['scam_flags'] as String) as List).cast<String>(),
    matchScore: row['match_score'] as int?,
  );
}
