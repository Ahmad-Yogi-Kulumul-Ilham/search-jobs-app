import 'package:sqlite3/sqlite3.dart';

import '../models/custom_source.dart';

/// Which built-in sources are switched on, and the sources the user added.
class SourceStore {
  SourceStore(this._db);

  final Database _db;

  /// Ids of built-in sources the user switched off. Sources are on unless
  /// listed here.
  Set<String> disabledBuiltIns() => {
    for (final row in _db.select(
      'SELECT source_id FROM source_settings WHERE enabled = 0',
    ))
      row['source_id'] as String,
  };

  void setBuiltInEnabled(String sourceId, bool enabled) => _db.execute(
    '''
    INSERT INTO source_settings (source_id, enabled) VALUES (?, ?)
    ON CONFLICT (source_id) DO UPDATE SET enabled = excluded.enabled
    ''',
    [sourceId, enabled ? 1 : 0],
  );

  List<CustomSource> custom() => [
    for (final row in _db.select('SELECT * FROM custom_sources ORDER BY name'))
      CustomSource(
        id: row['id'] as int,
        kind:
            CustomSourceKind.byName(row['kind'] as String) ??
            CustomSourceKind.rss,
        name: row['name'] as String,
        value: row['value'] as String,
        enabled: row['enabled'] == 1,
      ),
  ];

  /// Stores a new custom source and returns it with its id. Returns null
  /// when the same feed or company board was already added.
  CustomSource? addCustom({
    required CustomSourceKind kind,
    required String name,
    required String value,
  }) {
    _db.execute(
      'INSERT OR IGNORE INTO custom_sources (kind, name, value) VALUES (?, ?, ?)',
      [kind.name, name.trim(), value.trim()],
    );
    if (_db.updatedRows == 0) return null;
    return CustomSource(
      id: _db.lastInsertRowId,
      kind: kind,
      name: name.trim(),
      value: value.trim(),
    );
  }

  void setCustomEnabled(int id, bool enabled) => _db.execute(
    'UPDATE custom_sources SET enabled = ? WHERE id = ?',
    [enabled ? 1 : 0, id],
  );

  void deleteCustom(int id) =>
      _db.execute('DELETE FROM custom_sources WHERE id = ?', [id]);
}
