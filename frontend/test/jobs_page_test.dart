import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import 'support.dart';

void main() {
  final rust = testJob(
    '1',
    title: 'Rust Engineer',
    company: 'Fortanix',
    location: 'Worldwide',
    jobType: 'Penuh waktu',
    salary: SalaryRange.of(
      90000,
      null,
      currency: 'USD',
      period: SalaryPeriod.year,
    ),
    descriptionHtml: '<p>Build <b>secure</b> systems.</p>',
  );
  final designer = testJob(
    '2',
    title: 'Product Designer',
    location: 'Europe',
    jobType: 'Kontrak',
    descriptionHtml: '<p>Design things people love.</p>',
    age: const Duration(days: 3),
  );

  testWidgets('filters jobs by seniority', (tester) async {
    final services = testServices(
      tester,
      jobs: [
        testJob('1', title: 'Senior Flutter Engineer'),
        testJob('2', title: 'Junior Designer'),
        testJob('3', title: 'Copywriter'),
      ],
    );
    await pumpApp(tester, services);

    await tester.tap(find.text('Level'));
    await tester.pumpAndSettle();
    expect(find.text('Junior (1)'), findsOneWidget);
    expect(find.text('Senior (1)'), findsOneWidget);
    expect(find.text('Tidak disebut (1)'), findsOneWidget);
    expect(find.textContaining('Magang'), findsNothing);

    await tester.tap(find.text('Junior (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tidak disebut (1)'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1000, 600));
    await tester.pumpAndSettle();

    expect(find.text('Level (2)'), findsOneWidget);
    expect(find.text('Junior Designer'), findsOneWidget);
    expect(find.text('Copywriter'), findsOneWidget);
    expect(find.text('Senior Flutter Engineer'), findsNothing);
  });

  testWidgets('filters jobs by country', (tester) async {
    final services = testServices(
      tester,
      jobs: [
        rust,
        designer,
        testJob('3', title: 'Data Analyst', location: 'Remote - Singapore'),
        testJob('4', title: 'Support Agent', location: 'Remote - USA'),
      ],
    );
    await pumpApp(tester, services);
    expect(find.textContaining('4 lowongan'), findsOneWidget);

    await tester.tap(find.text('Negara'));
    await tester.pumpAndSettle();
    // Only places some job names are offered, with their counts.
    expect(find.text('Seluruh dunia (1)'), findsOneWidget);
    expect(find.text('Eropa (1)'), findsOneWidget);
    expect(find.text('Singapura (1)'), findsOneWidget);
    expect(find.text('Amerika Serikat (1)'), findsOneWidget);
    expect(find.textContaining('Jepang'), findsNothing);

    await tester.tap(find.text('Singapura (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seluruh dunia (1)'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(1000, 600));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 lowongan'), findsOneWidget);
    expect(find.text('Data Analyst'), findsOneWidget);
    expect(find.text('Rust Engineer'), findsOneWidget);
    expect(find.text('Support Agent'), findsNothing);
    expect(find.text('Negara (2)'), findsOneWidget);

    await tester.tap(find.text('Negara (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus pilihan negara'));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 lowongan'), findsOneWidget);
  });

  testWidgets('lists stored jobs, filters them, and opens one', (tester) async {
    final services = testServices(tester, jobs: [rust, designer]);
    await pumpApp(tester, services);

    expect(find.textContaining('2 lowongan'), findsOneWidget);
    expect(find.text('Rust Engineer'), findsOneWidget);
    expect(find.text('Fortanix · Worldwide'), findsOneWidget);
    expect(
      find.text('Pilih lowongan untuk melihat detailnya.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'designer');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.textContaining('1 lowongan'), findsOneWidget);
    expect(find.text('Rust Engineer'), findsNothing);

    await tester.tap(find.text('Product Designer'));
    await tester.pumpAndSettle();
    expect(find.text('Lamar di Remote OK'), findsOneWidget);
    expect(find.text('Lokasi terbatas'), findsOneWidget);
    expect(find.textContaining('Eropa Tengah 15.00–23.00 WIB'), findsOneWidget);
    expect(
      find.textContaining('Design things people love', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('quick filters narrow the list and reset restores it', (
    tester,
  ) async {
    await pumpApp(tester, testServices(tester, jobs: [rust, designer]));

    await tester.tap(find.widgetWithText(FilterChip, 'Bisa dari Indonesia'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 lowongan'), findsOneWidget);
    expect(find.text('Product Designer'), findsNothing);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 lowongan'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Ada gaji'));
    await tester.pumpAndSettle();
    expect(find.text('Rust Engineer'), findsOneWidget);
    expect(find.text('Product Designer'), findsNothing);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Jenis kerja'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Kontrak'));
    await tester.pumpAndSettle();
    expect(find.text('Jenis kerja (1)'), findsOneWidget);
    expect(find.text('Rust Engineer'), findsNothing);
    expect(find.text('Product Designer'), findsOneWidget);
  });

  testWidgets('shows salary in rupiah and tracks a saved job', (tester) async {
    final services = testServices(tester, jobs: [rust, designer]);
    await pumpApp(tester, services);

    await tester.tap(find.text('Rust Engineer'));
    await tester.pumpAndSettle();
    expect(find.text('Bisa dari Indonesia'), findsNWidgets(2));
    expect(
      find.text('USD 90.000 / tahun  ≈ Rp 135 jt / bulan'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Status: Disimpan'), findsOneWidget);
    expect(
      services.database.applications.find(rust.id)!.status,
      ApplicationStatus.saved,
    );

    await tester.tap(find.text('Status: Disimpan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Dilamar'));
    await tester.pumpAndSettle();
    expect(find.text('Status: Dilamar'), findsOneWidget);

    await openPage(tester, 'Lamaran');
    expect(find.text('Dilamar · 1'), findsOneWidget);
    expect(find.text('Disimpan · 0'), findsOneWidget);
    expect(find.text('Rust Engineer'), findsOneWidget);
  });

  testWidgets('hiding a job removes it until hidden jobs are restored', (
    tester,
  ) async {
    await pumpApp(tester, testServices(tester, jobs: [rust, designer]));

    await tester.tap(find.text('Rust Engineer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lainnya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sembunyikan lowongan ini'));
    await tester.pumpAndSettle();
    expect(find.text('Rust Engineer'), findsNothing);
    expect(find.textContaining('1 lowongan'), findsOneWidget);

    await openPage(tester, 'Pengaturan');
    // The AI settings come first, so scroll down to this section.
    await tester.dragUntilVisible(
      find.text('1 lowongan disembunyikan'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    expect(find.text('1 lowongan disembunyikan'), findsOneWidget);
    await tester.tap(find.text('Tampilkan semua lagi'));
    await tester.pumpAndSettle();
    expect(find.text('0 lowongan disembunyikan'), findsOneWidget);

    await openPage(tester, 'Lowongan');
    expect(find.text('Rust Engineer'), findsOneWidget);
  });
}
