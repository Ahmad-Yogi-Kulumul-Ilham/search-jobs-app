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
