import '../ai/ai_client.dart';
import '../ai/cv_reviewer.dart';
import '../data/app_database.dart';
import '../data/discovery_store.dart';
import '../models/custom_source.dart';
import '../models/job.dart';
import '../util/region.dart';
import 'sources.dart';

/// Fetches a source's current jobs, for checking it.
typedef SourceFetcher = Future<List<Job>> Function(JobSource source);

/// What one discovery run found.
class DiscoveryResult {
  const DiscoveryResult({
    this.found = const [],
    this.checkedCompanies = 0,
    this.remainingCompanies = 0,
    this.suggested = 0,
    this.unreadable = 0,
    this.usage,
  });

  /// Sources that answered and listed jobs, newly stored.
  final List<DiscoveredSource> found;

  /// Companies looked up this run, and those still waiting for a later run.
  final int checkedCompanies;
  final int remainingCompanies;

  /// For an AI search: how many sources it named, and how many of those
  /// could not be read and were dropped.
  final int suggested;
  final int unreadable;

  /// What the AI search cost; null for other runs.
  final AiUsage? usage;
}

/// Finds new sources: company boards behind the companies in stored jobs,
/// and sources an AI finds on the web. Every candidate is fetched once, so
/// only sources that work and list jobs are offered.
class SourceDiscovery {
  SourceDiscovery({
    required this.database,
    required this._fetch,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Companies looked up per run, most jobs first; the rest wait for the
  /// next run so one click stays around half a minute.
  static const batchSize = 40;

  /// A company with no board found is looked up again after this.
  static const recheckAfter = Duration(days: 30);

  static const _parallel = 6;
  static const _boardKinds = [
    CustomSourceKind.greenhouse,
    CustomSourceKind.lever,
    CustomSourceKind.ashby,
  ];

  final AppDatabase database;
  final SourceFetcher _fetch;
  final DateTime Function() _clock;

  /// Looks for boards linked from stored jobs, then for boards named after
  /// the next [batchSize] companies in stored jobs. [onProgress] gets the
  /// number of lookups done and the total.
  Future<DiscoveryResult> fromJobs({
    void Function(int done, int total)? onProgress,
  }) async {
    final store = database.discovery;
    final now = _clock();
    final checkedBefore = now.subtract(recheckAfter);
    final known = store.knownKeys();
    final found = <DiscoveredSource>[];

    final links = <({CustomSourceKind kind, String value})>[];
    for (final link in store.boardLinks()) {
      final board = boardFromLink(link);
      if (board != null && known.add('${board.kind.name}:${board.value}')) {
        links.add(board);
      }
    }
    final companies = store.companiesToCheck(
      checkedBefore: checkedBefore,
      limit: batchSize,
    );
    final total = links.length + companies.length;
    var done = 0;
    void step() => onProgress?.call(++done, total);

    // A link names the board exactly, so it needs no title match.
    await _inParallel(links, (board) async {
      final hit = await _check(
        board.kind,
        board.value,
        name: board.value[0].toUpperCase() + board.value.substring(1),
        origin: DiscoveryOrigin.link,
        now: now,
      );
      if (hit != null) {
        store.save(hit);
        found.add(hit);
      }
      step();
    });

    await _inParallel(companies, (company) async {
      final titles = store.titlesOf(company);
      DiscoveredSource? best;
      search:
      for (final kind in _boardKinds) {
        for (final slug in slugCandidates(company)) {
          // Two companies can share a slug; one lookup is enough.
          if (!known.add('${kind.name}:$slug')) continue;
          final hit = await _check(
            kind,
            slug,
            name: company,
            origin: DiscoveryOrigin.company,
            titles: titles,
            now: now,
          );
          if (hit == null) continue;
          if (best == null ||
              (hit.verified && !best.verified) ||
              (hit.verified == best.verified &&
                  hit.remoteJobs > best.remoteJobs)) {
            best = hit;
          }
          if (hit.verified) break search;
        }
      }
      if (best != null) {
        store.save(best);
        found.add(best);
      }
      store.markChecked(company, now);
      step();
    });

    return DiscoveryResult(
      found: found,
      checkedCompanies: companies.length,
      remainingCompanies: store.countCompaniesToCheck(
        checkedBefore: checkedBefore,
      ),
    );
  }

  /// Asks [ai] to search the web for new sources, optionally about [focus]
  /// such as "desain" or "data", and keeps the ones that work.
  Future<DiscoveryResult> withAi(AiClient ai, {String focus = ''}) async {
    final store = database.discovery;
    final now = _clock();
    final known = store.knownKeys();
    final added = [
      for (final source in database.sources.custom())
        '- ${source.name} (${source.kind.label}: ${source.value})',
    ];
    final result = await ai.searchJson(
      system: _aiSystem,
      prompt: [
        focus.trim().isEmpty
            ? 'Find new sources of remote jobs, in any field.'
            : 'Find new sources of remote jobs for this focus: '
                  '${focus.trim()}.',
        if (added.isNotEmpty)
          'Already added, so do not suggest these:\n${added.join('\n')}',
      ].join('\n\n'),
    );

    final items = result.json['sources'] is List
        ? result.json['sources'] as List
        : const [];
    final candidates =
        <({CustomSourceKind kind, String value, String name, String note})>[];
    var unreadable = 0;
    for (final item in items) {
      if (item is! Map) continue;
      final parsed = parseSourceInput('${item['url'] ?? ''}');
      if (parsed == null) {
        unreadable++;
        continue;
      }
      if (!known.add('${parsed.kind.name}:${parsed.value.toLowerCase()}')) {
        continue;
      }
      final name = '${item['name'] ?? ''}'.trim();
      candidates.add((
        kind: parsed.kind,
        value: parsed.value,
        name: name.isEmpty ? parsed.suggestedName : name,
        note: '${item['reason'] ?? ''}'.trim(),
      ));
    }

    final found = <DiscoveredSource>[];
    await _inParallel(candidates, (candidate) async {
      final hit = await _check(
        candidate.kind,
        candidate.value,
        name: candidate.name,
        origin: DiscoveryOrigin.ai,
        note: candidate.note,
        now: now,
      );
      if (hit == null) {
        unreadable++;
        return;
      }
      store.save(hit);
      found.add(hit);
    });
    return DiscoveryResult(
      found: found,
      suggested: items.length,
      unreadable: unreadable,
      usage: AiUsage(model: result.model, costUsd: result.costUsd),
    );
  }

  /// Fetches a candidate once. Returns it when it answers with jobs; with
  /// [titles], it counts as verified only when one of its jobs has one of
  /// those titles.
  Future<DiscoveredSource?> _check(
    CustomSourceKind kind,
    String value, {
    required String name,
    required DiscoveryOrigin origin,
    required DateTime now,
    Set<String>? titles,
    String note = '',
  }) async {
    final List<Job> jobs;
    try {
      jobs = await _fetch(
        sourceFor(CustomSource(id: 0, kind: kind, name: name, value: value)),
      );
    } on Exception {
      return null;
    }
    if (jobs.isEmpty) return null;
    return DiscoveredSource(
      kind: kind,
      value: value,
      name: name,
      origin: origin,
      note: note,
      remoteJobs: jobs.length,
      openJobs: jobs.where((job) => job.regionFit == RegionFit.open).length,
      verified:
          titles == null ||
          jobs.any((job) => titles.contains(normalizeTitle(job.title))),
      foundAt: now,
    );
  }

  /// Runs [task] on every item, a few at a time.
  Future<void> _inParallel<T>(
    List<T> items,
    Future<void> Function(T item) task,
  ) async {
    var next = 0;
    Future<void> worker() async {
      while (next < items.length) {
        await task(items[next++]);
      }
    }

    await Future.wait([for (var i = 0; i < _parallel; i++) worker()]);
  }
}

/// The company board a link points at, or null for other links. Greenhouse
/// embeds name the company in a `for` parameter.
({CustomSourceKind kind, String value})? boardFromLink(String link) {
  final uri = Uri.tryParse(link);
  final embedded = uri?.queryParameters['for'];
  if (uri != null &&
      uri.host.endsWith('greenhouse.io') &&
      embedded != null &&
      embedded.isNotEmpty) {
    return (kind: CustomSourceKind.greenhouse, value: embedded.toLowerCase());
  }
  final parsed = parseSourceInput(link);
  if (parsed == null || parsed.kind == CustomSourceKind.rss) return null;
  return (kind: parsed.kind, value: parsed.value);
}

const _suffixes = {
  'inc',
  'llc',
  'ltd',
  'limited',
  'gmbh',
  'corp',
  'corporation',
  'co',
  'company',
  'technologies',
  'technology',
  'labs',
  'group',
  'holdings',
  'hq',
  'io',
  'ai',
  'app',
};

/// Board names a company might use: `Grafana Labs` gives `grafanalabs`,
/// `grafana-labs`, and `grafana`.
List<String> slugCandidates(String company) {
  final words = company
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .split(' ')
      .where((word) => word.isNotEmpty)
      .toList();
  final core = words.where((word) => !_suffixes.contains(word)).toList();
  return {
    words.join(),
    words.join('-'),
    if (core.isNotEmpty) core.join(),
  }.where((slug) => slug.length >= 2).toList();
}

const _aiSystem =
    'You research where a job seeker based in Indonesia can find remote '
    'jobs. Use web search to find job sources that are active now.\n\n'
    'Each source must be one of:\n'
    '- the public job board of a company that hires remotely, ideally '
    'worldwide or in Asia-Pacific, on Greenhouse '
    '(https://boards.greenhouse.io/<company>), Lever '
    '(https://jobs.lever.co/<company>), or Ashby '
    '(https://jobs.ashbyhq.com/<company>);\n'
    '- the RSS or Atom feed URL of a job site that lists remote jobs (a feed '
    'of job postings, not a blog).\n\n'
    'Only give URLs you saw in search results; each one is fetched to check '
    'it. Prefer sources that hire people outside the US and Europe. Give up '
    'to 15 sources, most promising first.\n\n'
    'Answer with only a JSON object, no other text, in this shape: '
    '{"sources": [{"name": "...", "url": "...", "reason": "..."}]}. Write '
    'each reason in Indonesian: one short sentence on why it suits someone '
    'in Indonesia.';
