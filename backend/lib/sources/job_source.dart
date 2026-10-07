import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/job.dart';

/// Thrown when a source answers with something other than a usable job list.
class SourceException implements Exception {
  const SourceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// A job board the app reads postings from through its public API or feed.
abstract class JobSource {
  const JobSource();

  /// Stable key stored with every job; never change it once released.
  String get id;

  /// Shown to the user as the origin of a posting.
  String get name;

  Uri get endpoint;

  /// A lighter address that lists the same jobs without full descriptions,
  /// for checking a source rather than storing its jobs.
  Uri get listingEndpoint => endpoint;

  /// The shortest gap between two fetches that the source's terms allow.
  Duration get minRefreshInterval => const Duration(hours: 1);

  /// Converts a raw response body into jobs. Throws [FormatException] when
  /// the body does not have the expected shape.
  List<Job> parse(String body);

  /// Fetches the jobs; with [listingOnly], from [listingEndpoint].
  Future<List<Job>> fetch(
    http.Client client, {
    bool listingOnly = false,
  }) async {
    final response = await client
        .get(
          listingOnly ? listingEndpoint : endpoint,
          headers: const {
            'User-Agent': 'search-jobs-app/1.0 (personal desktop job reader)',
            'Accept': 'application/json, application/rss+xml, */*',
          },
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw SourceException('HTTP ${response.statusCode}');
    }
    // Decode as UTF-8 ourselves: without a charset header the http package
    // falls back to Latin-1 and garbles non-ASCII text.
    return parse(utf8.decode(response.bodyBytes, allowMalformed: true));
  }
}

/// Reads a JSON value as trimmed text, treating null as empty.
String asText(Object? value) => value == null ? '' : value.toString().trim();

/// Reads a JSON value as a number; some sources send numbers as strings.
num? asNum(Object? value) => value is num ? value : num.tryParse(asText(value));

/// Reads a JSON value as a list of non-empty strings. Some sources send a
/// single string where others send an array.
List<String> asTextList(Object? value) {
  final items = value is List ? value : [?value];
  return [
    for (final item in items)
      if (asText(item).isNotEmpty) asText(item),
  ];
}

/// Decodes a JSON body and returns the list found under [key], or the body
/// itself when [key] is null.
List<Object?> decodeJobList(String body, {String? key}) {
  final Object? decoded = jsonDecode(body);
  final Object? list = key == null
      ? decoded
      : (decoded is Map ? decoded[key] : null);
  if (list is! List) {
    throw const FormatException('Daftar lowongan tidak ditemukan');
  }
  return list;
}
