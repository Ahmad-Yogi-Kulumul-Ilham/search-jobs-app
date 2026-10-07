import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../models/job.dart';
import '../util/region.dart';
import '../util/seniority.dart';
import 'alert_store.dart';
import 'application_store.dart';
import 'cv_store.dart';
import 'discovery_store.dart';
import 'job_store.dart';
import 'settings_store.dart';
import 'source_store.dart';

/// The app's local SQLite database. Opening it brings the schema up to date;
/// reading and writing goes through the stores.
class AppDatabase {
  AppDatabase._(this.sql) {
    _migrate();
  }

  factory AppDatabase.open(String path) => AppDatabase._(sqlite3.open(path));

  factory AppDatabase.inMemory() => AppDatabase._(sqlite3.openInMemory());

  /// The raw connection, for the stores in this package.
  final Database sql;

  late final JobStore jobs = JobStore(sql);
  late final ApplicationStore applications = ApplicationStore(sql);
  late final SourceStore sources = SourceStore(sql);
  late final SettingsStore settings = SettingsStore(sql);
  late final AlertStore alerts = AlertStore(sql);
  late final CvStore cvs = CvStore(sql);
  late final DiscoveryStore discovery = DiscoveryStore(sql);

  void close() => sql.close();

  void _migrate() {
    final version = sql.select('PRAGMA user_version').first.values.first as int;
    for (var next = version + 1; next <= _migrations.length; next++) {
      sql.execute('BEGIN');
      try {
        _migrations[next - 1](sql);
        sql.execute('PRAGMA user_version = $next');
        sql.execute('COMMIT');
      } catch (_) {
        sql.execute('ROLLBACK');
        rethrow;
      }
    }
  }
}

/// Schema changes in order; entry `n - 1` takes the database to version `n`.
/// Released entries must never be edited, only followed by new ones.
final List<void Function(Database)> _migrations = [
  (sql) => sql.execute('''
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
  '''),
  (sql) {
    sql.execute('''
      ALTER TABLE jobs ADD COLUMN salary_min REAL;
      ALTER TABLE jobs ADD COLUMN salary_max REAL;
      ALTER TABLE jobs ADD COLUMN salary_currency TEXT;
      ALTER TABLE jobs ADD COLUMN salary_period TEXT;
      ALTER TABLE jobs ADD COLUMN region_fit TEXT NOT NULL DEFAULT 'unknown';
      ALTER TABLE jobs ADD COLUMN hidden INTEGER NOT NULL DEFAULT 0;
      CREATE TABLE applications (
        job_id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        title TEXT NOT NULL,
        company TEXT NOT NULL,
        url TEXT NOT NULL,
        source_id TEXT NOT NULL,
        location TEXT NOT NULL,
        notes TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        applied_at INTEGER,
        interview_at INTEGER,
        updated_at INTEGER NOT NULL
      );
      CREATE TABLE blocked_companies (name TEXT PRIMARY KEY);
      CREATE TABLE source_settings (
        source_id TEXT PRIMARY KEY,
        enabled INTEGER NOT NULL
      );
      CREATE TABLE custom_sources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kind TEXT NOT NULL,
        name TEXT NOT NULL,
        value TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        UNIQUE (kind, value)
      );
      CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    ''');
    for (final row in sql.select('SELECT id, location FROM jobs')) {
      sql.execute('UPDATE jobs SET region_fit = ? WHERE id = ?', [
        classifyRegion(row['location'] as String).name,
        row['id'],
      ]);
    }
    // Stored jobs predate the salary columns; fetching again fills them in.
    sql.execute('DELETE FROM source_state');
  },
  (sql) {
    sql.execute('''
      ALTER TABLE jobs ADD COLUMN scam_flags TEXT NOT NULL DEFAULT '[]';
      ALTER TABLE applications ADD COLUMN followed_up_at INTEGER;
      CREATE TABLE alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        filter TEXT NOT NULL
      );
    ''');
    final rows = sql.select(
      'SELECT id, title, company, description_html FROM jobs',
    );
    for (final row in rows) {
      final warnings = warningsFor(
        Job(
          id: row['id'] as String,
          sourceId: '',
          title: row['title'] as String,
          company: row['company'] as String,
          url: '',
          descriptionHtml: row['description_html'] as String,
        ),
      );
      sql.execute('UPDATE jobs SET scam_flags = ? WHERE id = ?', [
        jsonEncode(warnings),
        row['id'],
      ]);
    }
  },
  (sql) => sql.execute('''
    CREATE TABLE cvs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      file_name TEXT NOT NULL,
      format TEXT NOT NULL,
      bytes BLOB NOT NULL,
      text TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE reviews (
      job_id TEXT NOT NULL,
      cv_id INTEGER NOT NULL,
      score INTEGER NOT NULL,
      result TEXT NOT NULL,
      model TEXT NOT NULL,
      cost_usd REAL NOT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (job_id, cv_id)
    );
    CREATE TABLE answers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      question TEXT NOT NULL,
      answer TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    );
    CREATE TABLE ai_spend (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cost_usd REAL NOT NULL,
      created_at INTEGER NOT NULL
    );
  '''),
  (sql) => sql.execute('''
    CREATE TABLE discovered_sources (
      kind TEXT NOT NULL,
      value TEXT NOT NULL,
      name TEXT NOT NULL,
      origin TEXT NOT NULL,
      note TEXT NOT NULL,
      remote_jobs INTEGER NOT NULL,
      open_jobs INTEGER NOT NULL,
      verified INTEGER NOT NULL,
      found_at INTEGER NOT NULL,
      dismissed INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (kind, value)
    );
    CREATE TABLE discovery_checked (
      company TEXT PRIMARY KEY,
      checked_at INTEGER NOT NULL
    );
  '''),
  (sql) {
    sql.execute(
      "ALTER TABLE jobs ADD COLUMN countries TEXT NOT NULL DEFAULT ''",
    );
    for (final row in sql.select('SELECT id, location FROM jobs')) {
      sql.execute('UPDATE jobs SET countries = ? WHERE id = ?', [
        storedPlaces(row['location'] as String),
        row['id'],
      ]);
    }
  },
  (sql) {
    sql.execute('''
      ALTER TABLE jobs ADD COLUMN seniority TEXT NOT NULL DEFAULT '';
      CREATE TABLE interview_preps (
        job_id TEXT NOT NULL,
        cv_id INTEGER NOT NULL,
        result TEXT NOT NULL,
        model TEXT NOT NULL,
        cost_usd REAL NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (job_id, cv_id)
      );
    ''');
    for (final row in sql.select('SELECT id, title FROM jobs')) {
      sql.execute('UPDATE jobs SET seniority = ? WHERE id = ?', [
        seniorityOf(row['title'] as String)?.name ?? '',
        row['id'],
      ]);
    }
  },
];
