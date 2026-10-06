import '../util/format.dart';

/// The period a salary amount is quoted for.
enum SalaryPeriod {
  hour('jam', 160),
  week('minggu', 52 / 12),
  month('bulan', 1),
  year('tahun', 1 / 12);

  const SalaryPeriod(this.label, this.perMonth);

  final String label;

  /// Multiplier from an amount per this period to an amount per month,
  /// assuming full-time work (40 hours a week).
  final double perMonth;

  /// Reads a period from free text such as `yearly`, `/hr`, or `per month`.
  static SalaryPeriod? parse(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'hour|/\s*hr|\bhr\b').hasMatch(lower)) return hour;
    if (lower.contains('week')) return week;
    if (RegExp(r'month|/\s*mo\b').hasMatch(lower)) return month;
    if (RegExp(r'year|annual|annum|/\s*yr|\byr\b').hasMatch(lower)) return year;
    return null;
  }
}

/// A salary in a form that can be compared and converted, unlike the free
/// text most postings carry.
class SalaryRange {
  const SalaryRange({this.min, this.max, this.currency = '', this.period});

  /// Builds a range from source values, where 0 or null means "not given".
  /// Returns null when neither bound is known.
  static SalaryRange? of(
    num? min,
    num? max, {
    String currency = '',
    SalaryPeriod? period,
  }) {
    final low = (min ?? 0) > 0 ? min!.toDouble() : null;
    final high = (max ?? 0) > 0 ? max!.toDouble() : null;
    if (low == null && high == null) return null;
    return SalaryRange(
      min: low,
      max: high,
      currency: currency.trim().toUpperCase(),
      period: period,
    );
  }

  final double? min;
  final double? max;

  /// ISO 4217 code such as `USD`, or empty when the source did not say.
  final String currency;
  final SalaryPeriod? period;

  /// Text such as `USD 60.000 – 90.000 / tahun`.
  String get label {
    final low = min, high = max;
    final amount = low != null && high != null && low != high
        ? '${thousands(low)} – ${thousands(high)}'
        : thousands(low ?? high ?? 0);
    return [
      if (currency.isNotEmpty) currency,
      amount,
      if (period != null) '/ ${period!.label}',
    ].join(' ');
  }

  @override
  bool operator ==(Object other) =>
      other is SalaryRange &&
      other.min == min &&
      other.max == max &&
      other.currency == currency &&
      other.period == period;

  @override
  int get hashCode => Object.hash(min, max, currency, period);

  @override
  String toString() => 'SalaryRange($label)';
}

const _currencyToken = r'(US\$|[$€£]|USD|EUR|GBP|AUD|CAD|SGD|CHF)';
const _amountToken = r'(\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?)\s*(k)?';
final _salaryPattern = RegExp(
  '$_currencyToken\\s*$_amountToken'
  '(?:\\s*(?:-|–|—|to)\\s*$_currencyToken?\\s*$_amountToken)?',
  caseSensitive: false,
);

const _currencySymbols = {r'$': 'USD', r'US$': 'USD', '€': 'EUR', '£': 'GBP'};

/// Best-effort reading of salary text such as `$45-$120/Hour` or
/// `€110K – €185K`. Returns null when no amount with a currency is found.
SalaryRange? parseSalaryText(String text) {
  final match = _salaryPattern.firstMatch(text);
  if (match == null) return null;

  double amount(String digits, String? thousand) =>
      double.parse(digits.replaceAll(',', '')) * (thousand == null ? 1 : 1000);

  var low = amount(match[2]!, match[3]);
  final high = match[5] == null ? null : amount(match[5]!, match[6]);
  // "$100-150k" means 100k to 150k.
  if (high != null && match[3] == null && match[6] != null && low < 1000) {
    low *= 1000;
  }
  final top = high ?? low;
  final token = match[1]!.toUpperCase();
  return SalaryRange.of(
    low,
    high,
    currency: _currencySymbols[token] ?? token,
    // Without a stated period, only clearly yearly or hourly sizes are safe
    // to guess; anything in between is left unknown.
    period:
        SalaryPeriod.parse(text) ??
        (top >= 20000
            ? SalaryPeriod.year
            : top <= 500
            ? SalaryPeriod.hour
            : null),
  );
}
