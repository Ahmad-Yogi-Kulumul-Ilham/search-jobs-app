import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

/// Small named values the app keeps between runs.
class SettingsStore {
  SettingsStore(this._db);

  final Database _db;

  String? get(String key) {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void set(String key, String value) => _db.execute(
    '''
    INSERT INTO settings (key, value) VALUES (?, ?)
    ON CONFLICT (key) DO UPDATE SET value = excluded.value
    ''',
    [key, value],
  );

  void remove(String key) =>
      _db.execute('DELETE FROM settings WHERE key = ?', [key]);

  /// Reads a value stored with [setJson]. Returns null when it is missing or
  /// no longer parses, so callers fall back to their default.
  Object? getJson(String key) {
    final text = get(key);
    if (text == null) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  void setJson(String key, Object? value) => set(key, jsonEncode(value));
}
