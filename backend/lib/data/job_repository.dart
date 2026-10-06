import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../sources/sources.dart';
import 'job_database.dart';

/// What one refresh did, keyed by source name.
class RefreshResult {
  const RefreshResult({
    this.fetched = const {},
    this.errors = const {},
    this.skipped = const [],
  });

  /// Number of jobs received from each source that was fetched.
  final Map<String, int> fetched;

  /// A short reason for each source that failed.
  final Map<String, String> errors;

  /// Sources left alone because they were fetched too recently.
  final List<String> skipped;
}

/// Pulls jobs from the sources into the local database.
class JobRepository {
  JobRepository({
    required this.database,
    required this.sources,
    http.Client? client,
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  /// A source is refreshed automatically once its data is older than this.
  static const autoRefreshAfter = Duration(hours: 6);

  final JobDatabase database;
  final List<JobSource> sources;
  final http.Client _client;
  final DateTime Function() _clock;

  String sourceName(String sourceId) {
    for (final source in sources) {
      if (source.id == sourceId) return source.name;
    }
    return sourceId;
  }

  /// Fetches every source that is due. An automatic refresh waits for
  /// [autoRefreshAfter]; a [manual] one only respects each source's own
  /// minimum interval. One source failing does not stop the others.
  Future<RefreshResult> refresh({required bool manual}) async {
    final fetched = <String, int>{};
    final errors = <String, String>{};
    final skipped = <String>[];

    Future<void> refreshSource(JobSource source) async {
      final last = database.lastFetchedAt(source.id);
      final wait = manual ? source.minRefreshInterval : autoRefreshAfter;
      if (last != null && _clock().difference(last) < wait) {
        skipped.add(source.name);
        return;
      }
      try {
        final jobs = await source.fetch(_client);
        database.saveFetch(source.id, jobs, _clock());
        fetched[source.name] = jobs.length;
      } on Exception catch (error) {
        errors[source.name] = _describe(error);
      }
    }

    await Future.wait(sources.map(refreshSource));
    return RefreshResult(fetched: fetched, errors: errors, skipped: skipped);
  }
}

String _describe(Exception error) => switch (error) {
  SocketException() || http.ClientException() => 'tidak bisa terhubung',
  TimeoutException() => 'waktu tunggu habis',
  FormatException() => 'format data tidak dikenali',
  _ => error.toString(),
};
