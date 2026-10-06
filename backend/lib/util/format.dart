import 'package:html/parser.dart' as html_parser;

/// Strips tags and decodes entities such as `&amp;` from a short text field.
String plainText(String input) {
  if (!input.contains('&') && !input.contains('<')) return input.trim();
  return (html_parser.parseFragment(input).text ?? '').trim();
}

const _jobTypes = {
  'full time': 'Penuh waktu',
  'part time': 'Paruh waktu',
  'contract': 'Kontrak',
  'freelance': 'Freelance',
  'internship': 'Magang',
  'temporary': 'Sementara',
};

/// Sources spell job types differently (`full_time`, `Full-Time`); this maps
/// the known ones to one Indonesian label and leaves the rest as they are.
String jobTypeLabel(String raw) {
  final key = raw.toLowerCase().replaceAll(RegExp(r'[_\-\s]+'), ' ').trim();
  return _jobTypes[key] ?? raw.trim();
}

const _salaryPeriods = {
  'annual': 'tahun',
  'yearly': 'tahun',
  'year': 'tahun',
  'monthly': 'bulan',
  'month': 'bulan',
  'weekly': 'minggu',
  'week': 'minggu',
  'hourly': 'jam',
  'hour': 'jam',
};

/// Formats a salary range like `USD 60.000 – 90.000 / tahun`. Sources send 0
/// or null when a bound is unknown; returns an empty string when both are.
String formatSalary(
  num? min,
  num? max, {
  String currency = '',
  String period = '',
}) {
  final low = (min ?? 0) > 0 ? min! : null;
  final high = (max ?? 0) > 0 ? max! : null;
  if (low == null && high == null) return '';
  final amount = low != null && high != null && low != high
      ? '${_thousands(low)} – ${_thousands(high)}'
      : _thousands(low ?? high!);
  final per = _salaryPeriods[period.toLowerCase().trim()];
  return [
    if (currency.isNotEmpty) currency,
    amount,
    if (per != null) '/ $per',
  ].join(' ');
}

String _thousands(num value) => value.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => '.',
);

final _hasTimeZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

/// Parses an ISO 8601 timestamp, reading one without a time zone as UTC.
DateTime? parseIsoUtc(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(_hasTimeZone.hasMatch(text) ? text : '${text}Z')
      ?.toUtc();
}

const _months = [
  'jan', 'feb', 'mar', 'apr', 'may', 'jun', //
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];

final _rfc822 = RegExp(
  r'(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})(?: ([+-])(\d{2})(\d{2}))?',
);

/// Parses an RSS date such as `Tue, 06 Oct 2026 08:44:40 +0000`.
DateTime? parseRfc822(String value) {
  final match = _rfc822.firstMatch(value);
  if (match == null) return null;
  final month = _months.indexOf(match[2]!.toLowerCase()) + 1;
  if (month == 0) return null;
  final utc = DateTime.utc(
    int.parse(match[3]!),
    month,
    int.parse(match[1]!),
    int.parse(match[4]!),
    int.parse(match[5]!),
    int.parse(match[6]!),
  );
  if (match[7] == null) return utc;
  final offset = Duration(
    hours: int.parse(match[8]!),
    minutes: int.parse(match[9]!),
  );
  return match[7] == '+' ? utc.subtract(offset) : utc.add(offset);
}

const _monthsId = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', //
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// A short Indonesian "time ago" label, switching to a date after a month.
String timeAgo(DateTime time, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(time);
  if (elapsed.inMinutes < 1) return 'baru saja';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes} menit lalu';
  if (elapsed.inDays < 1) return '${elapsed.inHours} jam lalu';
  if (elapsed.inDays < 30) return '${elapsed.inDays} hari lalu';
  final local = time.toLocal();
  return '${local.day} ${_monthsId[local.month - 1]} ${local.year}';
}
