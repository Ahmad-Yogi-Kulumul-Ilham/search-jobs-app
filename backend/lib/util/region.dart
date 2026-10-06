/// Whether a posting's stated location lets someone in Indonesia apply.
enum RegionFit {
  /// Worldwide, or a region that includes Indonesia.
  open,

  /// Names specific places, none of which include Indonesia.
  restricted,

  /// No location given, or only "Remote".
  unknown,
}

final _openPattern = RegExp(
  r'\b(worldwide|world wide|anywhere|global|globally|international|'
  r'indonesia|jakarta|asia|apac|asia[- ]pacific|south[- ]?east asia|sea|'
  r'all countries|any country|any location|earth)\b',
  caseSensitive: false,
);

final _vaguePattern = RegExp(
  r'^(remote|fully remote|100% remote|n/?a|-)?$',
  caseSensitive: false,
);

/// Classifies free-text location such as `Anywhere in the World`,
/// `USA, UK, Singapore`, or `Remote`. This reads only what the posting says:
/// a worldwide posting may still add limits in its description.
RegionFit classifyRegion(String location) {
  final text = location.trim();
  if (_vaguePattern.hasMatch(text)) return RegionFit.unknown;
  return _openPattern.hasMatch(text) ? RegionFit.open : RegionFit.restricted;
}

final _remotePattern = RegExp(
  r'remote|anywhere|worldwide|distributed|work from home|\bwfh\b',
  caseSensitive: false,
);

/// Whether a location on a company's own job board describes a remote role.
/// Company boards list office jobs too, unlike the remote-only job sites.
bool looksRemote(String location) => _remotePattern.hasMatch(location);
