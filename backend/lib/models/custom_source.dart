/// The kinds of source a user can add on top of the built-in job sites.
enum CustomSourceKind {
  rss('Feed RSS'),
  greenhouse('Greenhouse'),
  lever('Lever'),
  ashby('Ashby');

  const CustomSourceKind(this.label);

  final String label;

  static CustomSourceKind? byName(String? name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// A source the user added: an RSS feed, or one company's job board on
/// Greenhouse, Lever, or Ashby.
class CustomSource {
  const CustomSource({
    required this.id,
    required this.kind,
    required this.name,
    required this.value,
    this.enabled = true,
  });

  /// Database row id; 0 before the source is stored.
  final int id;
  final CustomSourceKind kind;

  /// Shown to the user, and used as the company name for company boards.
  final String name;

  /// The feed URL for [CustomSourceKind.rss], otherwise the company's board
  /// name, such as `gitlab` in `boards.greenhouse.io/gitlab`.
  final String value;
  final bool enabled;

  /// The id stored on this source's jobs.
  String get sourceId => 'custom:$id';
}

/// Works out what kind of source the user pasted: a link to a company board
/// on Greenhouse, Lever, or Ashby, or otherwise an RSS feed URL. Returns null
/// when [input] is not a usable web address.
({CustomSourceKind kind, String value, String suggestedName})? parseSourceInput(
  String input,
) {
  final text = input.trim();
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) return null;
  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  CustomSourceKind? board;
  if (host.endsWith('greenhouse.io')) board = CustomSourceKind.greenhouse;
  if (host.endsWith('lever.co')) board = CustomSourceKind.lever;
  if (host.endsWith('ashbyhq.com')) board = CustomSourceKind.ashby;
  if (board != null) {
    // API-style links put the company after a fixed prefix; public pages put
    // it first.
    const prefixes = {
      'v0',
      'v1',
      'boards',
      'postings',
      'posting-api',
      'job-board',
      'embed',
      'job_board',
    };
    final company = segments.where((s) => !prefixes.contains(s)).firstOrNull;
    if (company == null) return null;
    return (
      kind: board,
      value: company.toLowerCase(),
      suggestedName: company[0].toUpperCase() + company.substring(1),
    );
  }
  return (
    kind: CustomSourceKind.rss,
    value: uri.toString(),
    suggestedName: host.replaceFirst('www.', ''),
  );
}
