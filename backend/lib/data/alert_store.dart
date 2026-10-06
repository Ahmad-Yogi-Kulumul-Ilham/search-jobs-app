import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'job_store.dart';

/// A saved search. New jobs that match it are announced after a refresh.
class JobAlert {
  const JobAlert({required this.id, required this.name, required this.filter});

  final int id;
  final String name;
  final JobFilter filter;
}

/// The user's saved searches.
class AlertStore {
  AlertStore(this._db);

  final Database _db;

  List<JobAlert> all() => [
    for (final row in _db.select('SELECT * FROM alerts ORDER BY name'))
      JobAlert(
        id: row['id'] as int,
        name: row['name'] as String,
        filter: JobFilter.fromJson(
          jsonDecode(row['filter'] as String) as Map<String, Object?>,
        ),
      ),
  ];

  JobAlert add(String name, JobFilter filter) {
    _db.execute('INSERT INTO alerts (name, filter) VALUES (?, ?)', [
      name.trim(),
      jsonEncode(filter.toJson()),
    ]);
    return JobAlert(id: _db.lastInsertRowId, name: name.trim(), filter: filter);
  }

  void delete(int id) => _db.execute('DELETE FROM alerts WHERE id = ?', [id]);
}
