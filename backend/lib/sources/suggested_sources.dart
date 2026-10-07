import '../models/custom_source.dart';

/// How a suggestion is grouped on the "Temukan sumber" screen.
enum SuggestionGroup {
  openToAsia(
    'Sering terbuka untuk Asia atau seluruh dunia',
    'Banyak lowongannya bertuliskan Worldwide, Global, APAC, atau Asia.',
  ),
  remoteFirst(
    'Perusahaan remote-first',
    'Bekerja remote sejak awal, tapi banyak posisi dibatasi ke negara '
        'tertentu. Cek label "Bisa dari Indonesia" di tiap lowongan.',
  ),
  jobSites(
    'Situs dan feed lowongan',
    'Feed RSS dari situs lowongan. Tidak disaring otomatis, jadi sebagian '
        'feed juga memuat lowongan kantor.',
  );

  const SuggestionGroup(this.label, this.hint);

  final String label;
  final String hint;
}

/// A source the app recommends, ready to add with one click.
class SuggestedSource {
  const SuggestedSource({
    required this.kind,
    required this.name,
    required this.value,
    required this.description,
    required this.group,
  });

  final CustomSourceKind kind;
  final String name;

  /// Same meaning as [CustomSource.value]: a feed URL or a board name.
  final String value;

  /// One Indonesian sentence on what the source offers.
  final String description;
  final SuggestionGroup group;

  /// Whether [source] is this suggestion, already added by the user.
  bool matches(CustomSource source) =>
      source.kind == kind && source.value.toLowerCase() == value.toLowerCase();
}

/// Sources checked by hand in October 2026: each answered and listed remote
/// jobs. Company boards change, so the add button still probes before saving.
const List<SuggestedSource> suggestedSources = [
  // Open to Asia or worldwide.
  SuggestedSource(
    kind: CustomSourceKind.greenhouse,
    name: 'Canonical',
    value: 'canonical',
    description:
        'Pembuat Ubuntu. Hampir semua lowongannya "Home based - Worldwide".',
    group: SuggestionGroup.openToAsia,
  ),
  SuggestedSource(
    kind: CustomSourceKind.ashby,
    name: 'Supabase',
    value: 'supabase',
    description:
        'Database open source. Banyak posisi "Remote, Global" dan APAC.',
    group: SuggestionGroup.openToAsia,
  ),
  SuggestedSource(
    kind: CustomSourceKind.lever,
    name: 'Metabase',
    value: 'metabase',
    description:
        'Alat analitik data open source, sering membuka "Global Remote".',
    group: SuggestionGroup.openToAsia,
  ),
  SuggestedSource(
    kind: CustomSourceKind.ashby,
    name: 'Railway',
    value: 'railway',
    description: 'Platform deploy aplikasi; posisi engineering terbuka global.',
    group: SuggestionGroup.openToAsia,
  ),
  SuggestedSource(
    kind: CustomSourceKind.ashby,
    name: 'Oyster',
    value: 'oyster',
    description:
        'Platform HR untuk tim global; ada posisi APAC dan "Any Location".',
    group: SuggestionGroup.openToAsia,
  ),
  SuggestedSource(
    kind: CustomSourceKind.lever,
    name: 'Appen',
    value: 'appen',
    description:
        'Data dan anotasi untuk AI; ada posisi "Any" dan di Asia, termasuk '
        'yang bukan engineering.',
    group: SuggestionGroup.remoteFirst,
  ),
  SuggestedSource(
    kind: CustomSourceKind.lever,
    name: 'Binance',
    value: 'binance',
    description: 'Bursa kripto dengan banyak posisi remote di Asia.',
    group: SuggestionGroup.openToAsia,
  ),
  SuggestedSource(
    kind: CustomSourceKind.greenhouse,
    name: 'OKX',
    value: 'okx',
    description: 'Bursa kripto; ada posisi "Remote Roles - APAC".',
    group: SuggestionGroup.openToAsia,
  ),
  SuggestedSource(
    kind: CustomSourceKind.ashby,
    name: 'Zapier',
    value: 'zapier',
    description: 'Otomasi kerja, 100% remote; sesekali membuka posisi APAC.',
    group: SuggestionGroup.openToAsia,
  ),
  SuggestedSource(
    kind: CustomSourceKind.ashby,
    name: 'LiveKit',
    value: 'livekit',
    description:
        'Infrastruktur audio dan video real-time; sebagian posisi mencakup '
        'Asia-Pasifik (APJ).',
    group: SuggestionGroup.remoteFirst,
  ),

  // Remote-first companies.
  SuggestedSource(
    kind: CustomSourceKind.greenhouse,
    name: 'GitLab',
    value: 'gitlab',
    description: 'Salah satu perusahaan full-remote terbesar.',
    group: SuggestionGroup.remoteFirst,
  ),
  SuggestedSource(
    kind: CustomSourceKind.greenhouse,
    name: 'Mozilla',
    value: 'mozilla',
    description: 'Pembuat Firefox; banyak posisi remote.',
    group: SuggestionGroup.remoteFirst,
  ),
  SuggestedSource(
    kind: CustomSourceKind.greenhouse,
    name: 'Wikimedia Foundation',
    value: 'wikimedia',
    description: 'Organisasi di balik Wikipedia; semua posisinya remote.',
    group: SuggestionGroup.remoteFirst,
  ),
  SuggestedSource(
    kind: CustomSourceKind.greenhouse,
    name: 'Grafana Labs',
    value: 'grafanalabs',
    description: 'Alat monitoring open source; remote di banyak negara.',
    group: SuggestionGroup.remoteFirst,
  ),
  SuggestedSource(
    kind: CustomSourceKind.ashby,
    name: 'PostHog',
    value: 'posthog',
    description: 'Analitik produk open source, tim full-remote.',
    group: SuggestionGroup.remoteFirst,
  ),
  SuggestedSource(
    kind: CustomSourceKind.ashby,
    name: 'DuckDuckGo',
    value: 'duck-duck-go',
    description: 'Mesin pencari privasi, tim full-remote.',
    group: SuggestionGroup.remoteFirst,
  ),
  SuggestedSource(
    kind: CustomSourceKind.greenhouse,
    name: 'Sourcegraph',
    value: 'sourcegraph91',
    description: 'Alat pencarian kode dan AI untuk developer; full-remote.',
    group: SuggestionGroup.remoteFirst,
  ),
  SuggestedSource(
    kind: CustomSourceKind.greenhouse,
    name: 'Netlify',
    value: 'netlify',
    description: 'Platform hosting web, tim remote.',
    group: SuggestionGroup.remoteFirst,
  ),
  SuggestedSource(
    kind: CustomSourceKind.ashby,
    name: 'Buffer',
    value: 'buffer',
    description: 'Alat media sosial, terkenal transparan soal gaji dan remote.',
    group: SuggestionGroup.remoteFirst,
  ),
  SuggestedSource(
    kind: CustomSourceKind.ashby,
    name: 'Kit',
    value: 'kit',
    description: 'Platform email untuk kreator (dulu ConvertKit), full-remote.',
    group: SuggestionGroup.remoteFirst,
  ),
  SuggestedSource(
    kind: CustomSourceKind.greenhouse,
    name: 'Twilio',
    value: 'twilio',
    description: 'Platform komunikasi; ada posisi remote di India dan Asia.',
    group: SuggestionGroup.remoteFirst,
  ),
  SuggestedSource(
    kind: CustomSourceKind.greenhouse,
    name: 'Coinbase',
    value: 'coinbase',
    description:
        'Bursa kripto remote-first; ada posisi di Singapura dan India.',
    group: SuggestionGroup.remoteFirst,
  ),
  SuggestedSource(
    kind: CustomSourceKind.ashby,
    name: 'Linear',
    value: 'linear',
    description: 'Alat manajemen proyek; ada posisi di Singapura.',
    group: SuggestionGroup.remoteFirst,
  ),

  // Job sites and feeds.
  SuggestedSource(
    kind: CustomSourceKind.rss,
    name: 'Himalayas',
    value: 'https://himalayas.app/jobs/rss',
    description: 'Situs khusus lowongan remote, banyak yang terbuka global.',
    group: SuggestionGroup.jobSites,
  ),
  SuggestedSource(
    kind: CustomSourceKind.rss,
    name: 'Jobspresso',
    value: 'https://jobspresso.co/feed/?post_type=job_listing',
    description: 'Lowongan remote yang dikurasi manual.',
    group: SuggestionGroup.jobSites,
  ),
  SuggestedSource(
    kind: CustomSourceKind.rss,
    name: 'CryptoJobsList',
    value: 'https://cryptojobslist.com/rss',
    description: 'Lowongan kripto dan Web3; sekitar separuhnya remote.',
    group: SuggestionGroup.jobSites,
  ),
  SuggestedSource(
    kind: CustomSourceKind.rss,
    name: 'LaraJobs',
    value: 'https://larajobs.com/feed',
    description: 'Lowongan PHP dan Laravel, mayoritas remote.',
    group: SuggestionGroup.jobSites,
  ),
  SuggestedSource(
    kind: CustomSourceKind.rss,
    name: 'Python.org Jobs',
    value: 'https://www.python.org/jobs/feed/rss/',
    description: 'Papan lowongan resmi Python; campuran remote dan kantor.',
    group: SuggestionGroup.jobSites,
  ),
  SuggestedSource(
    kind: CustomSourceKind.rss,
    name: 'Rails Job Board',
    value: 'https://jobs.rubyonrails.org/jobs.rss',
    description: 'Lowongan Ruby on Rails; campuran remote dan kantor.',
    group: SuggestionGroup.jobSites,
  ),
  SuggestedSource(
    kind: CustomSourceKind.rss,
    name: 'Elixir Jobs',
    value: 'https://elixirjobs.net/rss',
    description: 'Lowongan Elixir; sekitar separuhnya remote.',
    group: SuggestionGroup.jobSites,
  ),
  SuggestedSource(
    kind: CustomSourceKind.rss,
    name: 'Dribbble Jobs',
    value: 'https://dribbble.com/jobs.rss',
    description:
        'Lowongan desain grafis, UI, dan UX; campuran remote dan kantor.',
    group: SuggestionGroup.jobSites,
  ),
  SuggestedSource(
    kind: CustomSourceKind.rss,
    name: 'WordPress Jobs',
    value: 'https://jobs.wordpress.net/feed/',
    description: 'Papan lowongan resmi WordPress, kebanyakan remote.',
    group: SuggestionGroup.jobSites,
  ),
];
