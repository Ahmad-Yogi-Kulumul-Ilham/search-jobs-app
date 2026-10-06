import 'package:sqlite3/sqlite3.dart';

import '../models/application.dart';
import '../models/job.dart';

/// The jobs the user is tracking and where each application stands.
class ApplicationStore {
  ApplicationStore(this._db);

  final Database _db;

  /// Every tracked job, most recently changed first.
  List<Application> all() => [
    for (final row in _db.select(
      'SELECT * FROM applications ORDER BY updated_at DESC, job_id',
    ))
      _fromRow(row),
  ];

  Application? find(String jobId) {
    final rows = _db.select('SELECT * FROM applications WHERE job_id = ?', [
      jobId,
    ]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  void save(Application application) => _db.execute(
    '''
    INSERT INTO applications (
      job_id, status, title, company, url, source_id, location, notes,
      created_at, applied_at, interview_at, followed_up_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT (job_id) DO UPDATE SET
      status = excluded.status,
      title = excluded.title,
      company = excluded.company,
      url = excluded.url,
      notes = excluded.notes,
      applied_at = excluded.applied_at,
      interview_at = excluded.interview_at,
      followed_up_at = excluded.followed_up_at,
      updated_at = excluded.updated_at
    ''',
    [
      application.jobId,
      application.status.name,
      application.title,
      application.company,
      application.url,
      application.sourceId,
      application.location,
      application.notes,
      application.createdAt.millisecondsSinceEpoch,
      application.appliedAt?.millisecondsSinceEpoch,
      application.interviewAt?.millisecondsSinceEpoch,
      application.followedUpAt?.millisecondsSinceEpoch,
      application.updatedAt.millisecondsSinceEpoch,
    ],
  );

  /// Records that the user chased the company for news, which restarts the
  /// follow-up reminder.
  Application? markFollowedUp(String jobId, {required DateTime now}) {
    final existing = find(jobId);
    if (existing == null) return null;
    final updated = existing.copyWith(followedUpAt: now, updatedAt: now);
    save(updated);
    return updated;
  }

  void delete(String jobId) =>
      _db.execute('DELETE FROM applications WHERE job_id = ?', [jobId]);

  /// Starts tracking a fetched job, or moves it to [status] when it already
  /// is tracked.
  Application track(
    Job job, {
    ApplicationStatus status = ApplicationStatus.saved,
    required DateTime now,
  }) {
    final existing = find(job.id);
    if (existing != null) return setStatus(job.id, status, now: now)!;
    final application = Application(
      jobId: job.id,
      status: status,
      title: job.title,
      company: job.company,
      url: job.url,
      sourceId: job.sourceId,
      location: job.location,
      createdAt: now,
      appliedAt: status == ApplicationStatus.saved ? null : now,
      updatedAt: now,
    );
    save(application);
    return application;
  }

  /// Tracks a job found outside the app's sources.
  Application addManual({
    required String title,
    required String company,
    required String url,
    ApplicationStatus status = ApplicationStatus.saved,
    required DateTime now,
  }) {
    final application = Application(
      jobId: '${Application.manualSourceId}:${now.microsecondsSinceEpoch}',
      status: status,
      title: title.trim(),
      company: company.trim(),
      url: url.trim(),
      createdAt: now,
      appliedAt: status == ApplicationStatus.saved ? null : now,
      updatedAt: now,
    );
    save(application);
    return application;
  }

  /// Moves an application to [status], stamping the applied date the first
  /// time it leaves "saved". Returns null when the job is not tracked.
  Application? setStatus(
    String jobId,
    ApplicationStatus status, {
    required DateTime now,
  }) {
    final existing = find(jobId);
    if (existing == null) return null;
    final updated = existing.copyWith(
      status: status,
      appliedAt: existing.appliedAt == null && status != ApplicationStatus.saved
          ? now
          : null,
      updatedAt: now,
    );
    save(updated);
    return updated;
  }
}

Application _fromRow(Row row) {
  DateTime? time(String column) {
    final value = row[column] as int?;
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  return Application(
    jobId: row['job_id'] as String,
    status:
        ApplicationStatus.byName(row['status'] as String) ??
        ApplicationStatus.saved,
    title: row['title'] as String,
    company: row['company'] as String,
    url: row['url'] as String,
    sourceId: row['source_id'] as String,
    location: row['location'] as String,
    notes: row['notes'] as String,
    createdAt: time('created_at')!,
    appliedAt: time('applied_at'),
    interviewAt: time('interview_at'),
    followedUpAt: time('followed_up_at'),
    updatedAt: time('updated_at')!,
  );
}
