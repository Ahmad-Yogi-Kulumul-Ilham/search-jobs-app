import 'package:flutter/material.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import '../../app_services.dart';
import '../common.dart';

/// App-wide settings and the lists of things the user chose not to see.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services,
      builder: (context, _) {
        final jobs = services.database.jobs;
        final hidden = jobs.hiddenCount();
        final blocked = jobs.blockedCompanies();
        final rates = services.rates;
        final rupiah = rates?.convert(1, from: 'USD', to: 'IDR');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(title: 'Pengaturan'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  const SectionTitle('Lowongan tersembunyi'),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('$hidden lowongan disembunyikan'),
                    trailing: TextButton(
                      onPressed: hidden == 0
                          ? null
                          : () {
                              jobs.unhideAll();
                              services.dataChanged();
                            },
                      child: const Text('Tampilkan semua lagi'),
                    ),
                  ),
                  const SectionTitle('Perusahaan diblokir'),
                  if (blocked.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Tidak ada perusahaan yang diblokir.'),
                    ),
                  for (final company in blocked)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(company),
                      trailing: TextButton(
                        onPressed: () {
                          jobs.unblockCompany(company);
                          services.dataChanged();
                        },
                        child: const Text('Buka blokir'),
                      ),
                    ),
                  const SectionTitle('Kurs'),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      rupiah == null
                          ? 'Kurs belum tersedia. Perkiraan gaji dalam Rupiah '
                                'muncul setelah pembaruan berikutnya berhasil.'
                          : '1 USD = Rp ${thousands(rupiah)} '
                                '(kurs referensi ${rates!.date}, dari '
                                'Frankfurter/Bank Sentral Eropa). Dipakai '
                                'untuk perkiraan gaji per bulan dalam Rupiah.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
