import 'package:test/test.dart';
import 'package:search_jobs_backend/util/format.dart';

void main() {
  test('formatSalary', () {
    expect(formatSalary(null, null), '');
    expect(formatSalary(0, 0, currency: 'USD'), '');
    expect(formatSalary(94150, 0, currency: 'USD'), 'USD 94.150');
    expect(
      formatSalary(5000, 7500, currency: 'EUR', period: 'monthly'),
      'EUR 5.000 – 7.500 / bulan',
    );
    expect(formatSalary(1200000, 1200000), '1.200.000');
  });

  test('jobTypeLabel', () {
    expect(jobTypeLabel('full_time'), 'Penuh waktu');
    expect(jobTypeLabel('Part-Time'), 'Paruh waktu');
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
}
