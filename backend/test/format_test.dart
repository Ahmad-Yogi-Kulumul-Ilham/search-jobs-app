import 'package:search_jobs_backend/search_jobs_backend.dart';
import 'package:test/test.dart';

void main() {
  test('SalaryRange.of treats 0 and null as unknown', () {
    expect(SalaryRange.of(null, null), isNull);
    expect(SalaryRange.of(0, 0, currency: 'USD'), isNull);
    expect(SalaryRange.of(94150, 0, currency: 'usd')!.label, 'USD 94.150');
    expect(
      SalaryRange.of(
        5000,
        7500,
        currency: 'EUR',
        period: SalaryPeriod.month,
      )!.label,
      'EUR 5.000 – 7.500 / bulan',
    );
    expect(SalaryRange.of(1200000, 1200000)!.label, '1.200.000');
  });

  test('parseSalaryText reads common salary spellings', () {
    expect(
      parseSalaryText(r'$45-$120/Hour'),
      SalaryRange.of(45, 120, currency: 'USD', period: SalaryPeriod.hour),
    );
    expect(
      parseSalaryText('€110K – €185K • Offers Equity'),
      SalaryRange.of(
        110000,
        185000,
        currency: 'EUR',
        period: SalaryPeriod.year,
      ),
    );
    expect(
      parseSalaryText(r'$100-150k per year'),
      SalaryRange.of(
        100000,
        150000,
        currency: 'USD',
        period: SalaryPeriod.year,
      ),
    );
    expect(
      parseSalaryText('USD 4,000 to 6,000 monthly'),
      SalaryRange.of(4000, 6000, currency: 'USD', period: SalaryPeriod.month),
    );
    // A mid-sized amount with no stated period is not guessed.
    expect(parseSalaryText('£3,500')!.period, isNull);
    expect(parseSalaryText('Competitive salary'), isNull);
    expect(parseSalaryText('3 years of experience'), isNull);
  });

  test('rupiahPerMonth converts through the base currency', () {
    const rates = ExchangeRates(
      base: 'USD',
      date: '2026-10-05',
      rates: {'IDR': 18000, 'EUR': 0.9},
    );
    String? rupiah(SalaryRange? salary) => rupiahPerMonth(salary!, rates);

    expect(
      rupiah(
        SalaryRange.of(
          60000,
          90000,
          currency: 'USD',
          period: SalaryPeriod.year,
        ),
      ),
      '≈ Rp 90 jt – 135 jt / bulan',
    );
    expect(
      rupiah(
        SalaryRange.of(25, null, currency: 'USD', period: SalaryPeriod.hour),
      ),
      '≈ Rp 72 jt / bulan',
    );
    expect(
      rupiah(
        SalaryRange.of(4500, null, currency: 'EUR', period: SalaryPeriod.month),
      ),
      '≈ Rp 90 jt / bulan',
    );
    expect(
      rupiah(
        SalaryRange.of(40, null, currency: 'USD', period: SalaryPeriod.month),
      ),
      '≈ Rp 720 rb / bulan',
    );
    // Unknown period or a currency without a rate cannot be converted.
    expect(rupiah(SalaryRange.of(5000, null, currency: 'USD')), isNull);
    expect(
      rupiah(
        SalaryRange.of(5000, null, currency: 'XYZ', period: SalaryPeriod.month),
      ),
      isNull,
    );
  });

  test('classifyRegion', () {
    for (final open in [
      'Anywhere in the World',
      'Worldwide',
      'Remote - Global',
      'APAC',
      'Americas, Europe, Asia',
      'Indonesia, Malaysia',
    ]) {
      expect(classifyRegion(open), RegionFit.open, reason: open);
    }
    for (final restricted in [
      'USA, UK, India, Singapore',
      'Remote, United States',
      'Europe',
      'Latin America',
      'Seattle, WA',
      'Eurasia',
    ]) {
      expect(
        classifyRegion(restricted),
        RegionFit.restricted,
        reason: restricted,
      );
    }
    for (final unknown in ['', 'Remote', ' fully remote ']) {
      expect(classifyRegion(unknown), RegionFit.unknown, reason: unknown);
    }
  });

  test('estimateWorkHoursWib shifts a 9-to-5 day into WIB', () {
    String hours(String location) =>
        estimateWorkHoursWib(location)
            .map((e) => '${e.region} ${e.wib}')
            .join('; ');

    expect(hours('Europe'), 'Eropa Tengah 15.00–23.00 WIB');
    expect(hours('India'), 'India 10.30–18.30 WIB');
    expect(
      hours('USA'),
      'Amerika Utara (Timur) 21.00–05.00 WIB; '
      'Amerika Utara (Barat) 00.00–08.00 WIB',
    );
    expect(
      hours('UK, Australia'),
      contains('Australia (Timur) 06.00–14.00 WIB'),
    );
    expect(hours('Anywhere in the World'), isEmpty);
  });

  test('jobTypeLabel', () {
    expect(jobTypeLabel('full_time'), 'Penuh waktu');
    expect(jobTypeLabel('Part-Time'), 'Paruh waktu');
    expect(jobTypeLabel('FullTime'), 'Penuh waktu');
    expect(jobTypeLabel('Volunteer'), 'Volunteer');
  });

  test('parseRfc822 applies the offset', () {
    expect(
      parseRfc822('Tue, 06 Oct 2026 08:44:40 +0700'),
      DateTime.utc(2026, 10, 6, 1, 44, 40),
    );
    expect(parseRfc822('yesterday'), isNull);
  });

  test('timeAgo', () {
    final now = DateTime(2026, 10, 6, 12);
    String ago(Duration elapsed) => timeAgo(now.subtract(elapsed), now: now);

    expect(ago(const Duration(seconds: 20)), 'baru saja');
    expect(ago(const Duration(minutes: 5)), '5 menit lalu');
    expect(ago(const Duration(hours: 3)), '3 jam lalu');
    expect(ago(const Duration(days: 4)), '4 hari lalu');
    expect(ago(const Duration(days: 40)), '27 Agu 2026');
  });

  test('parseSourceInput recognizes company boards and feeds', () {
    ({String kind, String value})? parsed(String input) {
      final result = parseSourceInput(input);
      return result == null
          ? null
          : (kind: result.kind.name, value: result.value);
    }

    expect(parsed('https://boards.greenhouse.io/gitlab'), (
      kind: 'greenhouse',
      value: 'gitlab',
    ));
    expect(parsed('job-boards.greenhouse.io/GitLab/jobs/123'), (
      kind: 'greenhouse',
      value: 'gitlab',
    ));
    expect(parsed('https://jobs.lever.co/spotify/abc-123'), (
      kind: 'lever',
      value: 'spotify',
    ));
    expect(parsed('https://jobs.ashbyhq.com/linear'), (
      kind: 'ashby',
      value: 'linear',
    ));
    expect(parsed('https://example.com/jobs.rss'), (
      kind: 'rss',
      value: 'https://example.com/jobs.rss',
    ));
    expect(parsed('https://jobs.lever.co/'), isNull);
    expect(parsed('gitlab'), isNull);
    expect(parsed(''), isNull);
  });
}
