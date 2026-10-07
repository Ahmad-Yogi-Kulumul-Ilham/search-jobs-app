import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../sources/sources.dart';
import 'app_database.dart';
import 'exchange_rates.dart';

/// What one refresh did, keyed by source name.
class RefreshResult {
  const RefreshResult({
    this.fetched = const {},
    this.errors = const {},
    this.skipped = const [],
    this.newJobIds = const [],
  });

  /// Number of jobs received from each source that was fetched.
  final Map<String, int> fetched;

  /// A short reason for each source that failed.
  final Map<String, String> errors;

  /// Sources left alone because they were fetched too recently.
  final List<String> skipped;

  /// Jobs this refresh stored for the first time.
  final List<String> newJobIds;
}

/// Pulls jobs from the active sources into the local database.
class JobRepository {
  JobRepository({
    required this.database,
    SourceRegistry? registry,
    http.Client? client,
    DateTime Function()? clock,
  }) : registry = registry ?? SourceRegistry(database.sources),
       _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  /// A source is refreshed automatically once its data is older than this.
  static const autoRefreshAfter = Duration(hours: 6);

  static const _ratesKey = 'exchange_rates';
  static const _ratesFetchedKey = 'exchange_rates_fetched_at';

  final AppDatabase database;
  final SourceRegistry registry;
  final http.Client _client;
  final DateTime Function() _clock;

  /// The last exchange rates fetched, or null before the first refresh.
  ExchangeRates? exchangeRates() {
    final json = database.settings.getJson(_ratesKey);
    if (json is! Map<String, Object?>) return null;
    try {
      return ExchangeRates.fromJson(json);
    } on TypeError {
      return null;
    }
  }

  /// Fetches every active source that is due. An automatic refresh waits for
  /// [autoRefreshAfter]; a [manual] one only respects each source's own
  /// minimum interval. One source failing does not stop the others.
  Future<RefreshResult> refresh({required bool manual}) async {
    final fetched = <String, int>{};
    final errors = <String, String>{};
    final skipped = <String>[];
    final newJobIds = <String>[];

    Future<void> refreshSource(JobSource source) async {
      final last = database.jobs.lastFetchedAt(source.id);
      final wait = manual ? source.minRefreshInterval : autoRefreshAfter;
      if (last != null && _clock().difference(last) < wait) {
        skipped.add(source.name);
        return;
      }
      try {
        final jobs = await source.fetch(_client);
        newJobIds.addAll(database.jobs.saveFetch(source.id, jobs, _clock()));
        fetched[source.name] = jobs.length;
      } on Exception catch (error) {
        errors[source.name] = describeFetchError(error);
      }
    }

    await Future.wait([
      ...registry.active().map(refreshSource),
      _refreshRates(),
    ]);
    return RefreshResult(
      fetched: fetched,
      errors: errors,
      skipped: skipped,
      newJobIds: newJobIds,
    );
  }

  /// Fetches [source] once without storing anything, to check that a source
  /// the user is adding works. Returns the number of jobs it lists.
  Future<int> probe(JobSource source) async =>
      (await source.fetch(_client)).length;

  /// Finds new sources to suggest, checking each with a light fetch.
  late final SourceDiscovery discovery = SourceDiscovery(
    database: database,
    fetch: (source) => source.fetch(_client, listingOnly: true),
    clock: _clock,
  );

  /// Rates change once per working day, so one fetch a day is plenty. A
  /// failure here only means salaries keep the previous conversion.
  Future<void> _refreshRates() async {
    final fetchedAt = int.tryParse(
      database.settings.get(_ratesFetchedKey) ?? '',
    );
    final now = _clock();
    if (fetchedAt != null &&
        now.millisecondsSinceEpoch - fetchedAt <
            const Duration(hours: 24).inMilliseconds) {
      return;
    }
    try {
      final rates = await fetchExchangeRates(_client);
      database.settings.setJson(_ratesKey, rates.toJson());
      database.settings.set(_ratesFetchedKey, '${now.millisecondsSinceEpoch}');
    } on Exception {
      return;
    }
  }
}

/// A short Indonesian reason for a failed fetch, for showing to the user.
String describeFetchError(Exception error) => switch (error) {
  SocketException() || http.ClientException() => 'tidak bisa terhubung',
  TimeoutException() => 'waktu tunggu habis',
  FormatException() => 'format data tidak dikenali',
  _ => error.toString(),
};
