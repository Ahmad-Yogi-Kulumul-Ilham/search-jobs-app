import 'package:sqlite3/sqlite3.dart';

import '../models/custom_source.dart';

/// How a discovered source was found.
enum DiscoveryOrigin {
  /// A company in the stored jobs turned out to have a board of its own.
  company,

  /// A stored job linked to a company board.
  link,

  /// An AI web search suggested it.
  ai;

  static DiscoveryOrigin byName(String name) =>
      values.where((origin) => origin.name == name).firstOrNull ?? company;
}

/// A source the app found and checked, offered to the user to add.
class DiscoveredSource {
  const DiscoveredSource({
    required this.kind,
    required this.value,
    required this.name,
    required this.origin,
    required this.remoteJobs,
    required this.openJobs,
    required this.verified,
    required this.foundAt,
    this.note = '',
  });

  final CustomSourceKind kind;

  /// Same meaning as [CustomSource.value]: a feed URL or a board name.
  final String value;
  final String name;
  final DiscoveryOrigin origin;

  /// Why the AI suggested it; empty for other origins.
  final String note;

  /// Remote jobs it listed when checked; every item for a feed.
  final int remoteJobs;

  /// Of those, the ones whose location is open to Indonesia.
  final int openJobs;

  /// False when a board was found only by its name, and none of its jobs
  /// matched the company's stored jobs: it may be another company.
  final bool verified;
  final DateTime foundAt;

  bool matches(CustomSource source) =>
      source.kind == kind && source.value.toLowerCase() == value.toLowerCase();
}

/// Sources found by discovery, and which companies were already checked.
class DiscoveryStore {
  DiscoveryStore(this._db);

  final Database _db;

  /// Found sources the user has not dismissed or added, newest and most
  /// promising first.
  List<DiscoveredSource> all() => [
    for (final row in _db.select('''
      SELECT * FROM discovered_sources d
      WHERE dismissed = 0 AND NOT EXISTS (
        SELECT 1 FROM custom_sources c
        WHERE c.kind = d.kind AND lower(c.value) = lower(d.value)
      )
      ORDER BY found_at DESC, verified DESC, open_jobs DESC, remote_jobs DESC
    '''))
      DiscoveredSource(
        kind:
            CustomSourceKind.byName(row['kind'] as String) ??
            CustomSourceKind.rss,
        value: row['value'] as String,
        name: row['name'] as String,
        origin: DiscoveryOrigin.byName(row['origin'] as String),
        note: row['note'] as String,
        remoteJobs: row['remote_jobs'] as int,
        openJobs: row['open_jobs'] as int,
        verified: row['verified'] == 1,
        foundAt: DateTime.fromMillisecondsSinceEpoch(row['found_at'] as int),
      ),
  ];

  /// Stores a found source, or refreshes its counts when it was found
  /// before; a dismissal stays.
  void save(DiscoveredSource source) => _db.execute(
    '''
    INSERT INTO discovered_sources
      (kind, value, name, origin, note, remote_jobs, open_jobs, verified,
       found_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT (kind, value) DO UPDATE SET
      remote_jobs = excluded.remote_jobs,
      open_jobs = excluded.open_jobs
    ''',
    [
      source.kind.name,
      // Kept as found: feed URLs can be case-sensitive.
      source.value,
      source.name,
      source.origin.name,
      source.note,
      source.remoteJobs,
      source.openJobs,
      source.verified ? 1 : 0,
      source.foundAt.millisecondsSinceEpoch,
    ],
  );

  void dismiss(CustomSourceKind kind, String value) => _db.execute(
    'UPDATE discovered_sources SET dismissed = 1 '
    'WHERE kind = ? AND lower(value) = lower(?)',
    [kind.name, value],
  );

  /// `kind:value` keys of every source already added, found, or dismissed,
  /// so discovery does not check them again.
  Set<String> knownKeys() => {
    for (final row in _db.select('''
      SELECT kind, lower(value) AS value FROM custom_sources
      UNION SELECT kind, lower(value) FROM discovered_sources
    '''))
      '${row['kind']}:${row['value']}',
  };

  /// Company names in stored jobs that are worth looking up, with the most
  /// jobs first: not checked since [checkedBefore], not blocked, not already
  /// a source, and not from a company board (those are the board itself).
  List<String> companiesToCheck({
    required DateTime checkedBefore,
    required int limit,
  }) => [
    for (final row in _db.select(
      '''
      SELECT company FROM jobs
      ${_companyFilter()}
      GROUP BY lower(trim(company))
      ORDER BY count(*) DESC, max(published_at) DESC
      LIMIT ?
      ''',
      [checkedBefore.millisecondsSinceEpoch, limit],
    ))
      (row['company'] as String).trim(),
  ];

  /// How many companies [companiesToCheck] would still offer.
  int countCompaniesToCheck({required DateTime checkedBefore}) =>
      _db.select(
            'SELECT count(DISTINCT lower(trim(company))) AS n FROM jobs '
            '${_companyFilter()}',
            [checkedBefore.millisecondsSinceEpoch],
          ).first['n']
          as int;

  String _companyFilter() => '''
    WHERE trim(company) != ''
      AND source_id NOT IN (
        SELECT 'custom:' || id FROM custom_sources WHERE kind != 'rss'
      )
      AND lower(trim(company)) NOT IN (
        SELECT lower(name) FROM custom_sources
        UNION SELECT lower(name) FROM blocked_companies
        UNION SELECT company FROM discovery_checked WHERE checked_at >= ?
      )
  ''';

  void markChecked(String company, DateTime at) => _db.execute(
    '''
    INSERT INTO discovery_checked (company, checked_at) VALUES (?, ?)
    ON CONFLICT (company) DO UPDATE SET checked_at = excluded.checked_at
    ''',
    [company.trim().toLowerCase(), at.millisecondsSinceEpoch],
  );

  /// Lowercased titles of [company]'s stored jobs, to recognize its board.
  Set<String> titlesOf(String company) => {
    for (final row in _db.select(
      'SELECT title FROM jobs WHERE lower(trim(company)) = ?',
      [company.trim().toLowerCase()],
    ))
      normalizeTitle(row['title'] as String),
  };

  /// Links in stored jobs that point at a Greenhouse, Lever, or Ashby
  /// board, from sources other than those boards themselves.
  List<String> boardLinks() {
    final pattern = RegExp(
      r'https?://(?:boards|job-boards)\.greenhouse\.io/[^\s"<>]+'
      r'|https?://jobs\.lever\.co/[^\s"<>]+'
      r'|https?://jobs\.ashbyhq\.com/[^\s"<>]+',
      caseSensitive: false,
    );
    final rows = _db.select('''
      SELECT url, description_html FROM jobs
      WHERE source_id NOT IN (
          SELECT 'custom:' || id FROM custom_sources WHERE kind != 'rss'
        )
        AND (url || description_html LIKE '%greenhouse.io/%'
          OR url || description_html LIKE '%jobs.lever.co/%'
          OR url || description_html LIKE '%jobs.ashbyhq.com/%')
    ''');
    return {
      for (final row in rows)
        for (final match in pattern.allMatches(
          '${row['url']} ${row['description_html']}',
        ))
          match.group(0)!,
    }.toList();
  }
}

/// Lowercase with punctuation and repeated spaces removed, so the same job
/// title from two sites compares equal.
String normalizeTitle(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
