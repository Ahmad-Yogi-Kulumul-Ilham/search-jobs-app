import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/salary.dart';

/// Currency rates against one base currency, as published for [date].
class ExchangeRates {
  const ExchangeRates({
    required this.base,
    required this.rates,
    required this.date,
  });

  factory ExchangeRates.fromJson(Map<String, Object?> json) => ExchangeRates(
    base: json['base'] as String,
    date: json['date'] as String,
    rates: {
      for (final entry in (json['rates'] as Map).entries)
        entry.key as String: (entry.value as num).toDouble(),
    },
  );

  final String base;

  /// How much of each currency one unit of [base] buys.
  final Map<String, double> rates;

  /// The day the rates were published, as `yyyy-MM-dd`.
  final String date;

  Map<String, Object?> toJson() => {'base': base, 'date': date, 'rates': rates};

  /// Converts [amount], or returns null when either currency is not covered.
  double? convert(double amount, {required String from, required String to}) {
    final fromRate = from == base ? 1.0 : rates[from];
    final toRate = to == base ? 1.0 : rates[to];
    if (fromRate == null || toRate == null) return null;
    return amount / fromRate * toRate;
  }
}

/// Fetches the latest reference rates from Frankfurter (European Central
/// Bank data, published once per working day).
Future<ExchangeRates> fetchExchangeRates(http.Client client) async {
  final response = await client
      .get(Uri.parse('https://api.frankfurter.dev/v1/latest?base=USD'))
      .timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) {
    throw http.ClientException('HTTP ${response.statusCode}');
  }
  final Object? json = jsonDecode(utf8.decode(response.bodyBytes));
  if (json is! Map<String, Object?> || json['rates'] is! Map) {
    throw const FormatException('Kurs tidak ditemukan');
  }
  return ExchangeRates.fromJson(json);
}

/// A salary as rupiah per month, such as `≈ Rp 75 jt – 112 jt / bulan`.
/// Returns null when the period or currency is unknown or not covered.
String? rupiahPerMonth(SalaryRange salary, ExchangeRates rates) {
  final period = salary.period;
  if (period == null || salary.currency.isEmpty) return null;

  double? monthly(double? amount) => amount == null
      ? null
      : rates.convert(
          amount * period.perMonth,
          from: salary.currency,
          to: 'IDR',
        );

  final low = monthly(salary.min);
  final high = monthly(salary.max);
  if (low == null && high == null) return null;
  final amount = low != null && high != null && low != high
      ? '${_compactRupiah(low)} – ${_compactRupiah(high)}'
      : _compactRupiah(low ?? high!);
  return '≈ Rp $amount / bulan';
}

String _compactRupiah(double value) {
  final (scaled, unit) = switch (value) {
    >= 1e9 => (value / 1e9, 'M'),
    >= 1e6 => (value / 1e6, 'jt'),
    _ => (value / 1e3, 'rb'),
  };
  final digits = scaled >= 100 ? 0 : 1;
  final text = scaled
      .toStringAsFixed(digits)
      .replaceFirst(RegExp(r'\.0$'), '')
      .replaceFirst('.', ',');
  return '$text $unit';
}
