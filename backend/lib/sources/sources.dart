import '../data/source_store.dart';
import '../models/application.dart';
import '../models/custom_source.dart';
import 'company_board_sources.dart';
import 'job_source.dart';
import 'jobicy_source.dart';
import 'remote_ok_source.dart';
import 'remotive_source.dart';
import 'rss_source.dart';
import 'we_work_remotely_source.dart';

export 'company_board_sources.dart';
export 'job_source.dart';
export 'jobicy_source.dart';
export 'remote_ok_source.dart';
export 'remotive_source.dart';
export 'rss_source.dart';
export 'source_discovery.dart';
export 'suggested_sources.dart';
export 'we_work_remotely_source.dart';

/// The job sites the app reads out of the box, in display order.
const List<JobSource> builtInSources = [
  RemoteOkSource(),
  JobicySource(),
  WeWorkRemotelySource(),
  RemotiveSource(),
];

/// Builds the reader for a source the user added.
JobSource sourceFor(CustomSource config) => switch (config.kind) {
  CustomSourceKind.rss => RssSource(
    id: config.sourceId,
    name: config.name,
    url: config.value,
  ),
  CustomSourceKind.greenhouse => GreenhouseSource(
    id: config.sourceId,
    name: config.name,
    board: config.value,
  ),
  CustomSourceKind.lever => LeverSource(
    id: config.sourceId,
    name: config.name,
    board: config.value,
  ),
  CustomSourceKind.ashby => AshbySource(
    id: config.sourceId,
    name: config.name,
    board: config.value,
  ),
};

/// The built-in sources together with the user's own, and which are on.
class SourceRegistry {
  SourceRegistry(this._store, {this.builtIn = builtInSources});

  final SourceStore _store;
  final List<JobSource> builtIn;

  /// The sources to fetch from: everything that is switched on.
  List<JobSource> active() {
    final off = _store.disabledBuiltIns();
    return [
      for (final source in builtIn)
        if (!off.contains(source.id)) source,
      for (final config in _store.custom())
        if (config.enabled) sourceFor(config),
    ];
  }

  /// Ids of switched-off sources, whose stored jobs stay out of the list.
  Set<String> disabledIds() => {
    ..._store.disabledBuiltIns(),
    for (final config in _store.custom())
      if (!config.enabled) config.sourceId,
  };

  /// The display name for a source id stored on a job or application.
  String nameOf(String sourceId) {
    if (sourceId == Application.manualSourceId) return 'Ditambahkan manual';
    for (final source in builtIn) {
      if (source.id == sourceId) return source.name;
    }
    for (final config in _store.custom()) {
      if (config.sourceId == sourceId) return config.name;
    }
    return 'Sumber yang sudah dihapus';
  }
}
