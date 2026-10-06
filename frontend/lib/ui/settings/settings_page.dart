import 'package:flutter/material.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import '../../app_services.dart';
import '../common.dart';

/// The Claude API key and model used for CV reviews and drafts.
class _AiSettings extends StatefulWidget {
  const _AiSettings({required this.services});

  final AppServices services;

  @override
  State<_AiSettings> createState() => _AiSettingsState();
}

class _AiSettingsState extends State<_AiSettings> {
  final _key = TextEditingController();

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  void _saveKey() {
    final key = _key.text.trim();
    if (key.isEmpty) return;
    if (!key.startsWith('sk-ant-')) {
      showMessage(
        context,
        'API key Anthropic biasanya diawali "sk-ant-". Periksa lagi.',
      );
      return;
    }
    widget.services.setApiKey(key);
    _key.clear();
    showMessage(context, 'API key tersimpan dan terenkripsi.');
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final key = services.apiKey;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('AI (Claude)'),
        const Text(
          'Dipakai untuk review CV, cover letter, dan draf jawaban. Butuh API '
          'key dari console.anthropic.com (berbeda dari langganan Claude Pro) '
          'dengan saldo terisi; biaya dihitung per pemakaian.',
        ),
        const SizedBox(height: 12),
        if (key != null)
          Row(
            children: [
              const Icon(Icons.key, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'API key tersimpan: sk-ant-…${key.substring(key.length - 4)}',
                ),
              ),
              TextButton(
                onPressed: () => services.setApiKey(null),
                child: const Text('Hapus'),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _key,
                  obscureText: true,
                  onSubmitted: (_) => _saveKey(),
                  decoration: const InputDecoration(
                    labelText: 'API key Anthropic',
                    hintText: 'sk-ant-…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: _saveKey, child: const Text('Simpan')),
            ],
          ),
        const SizedBox(height: 14),
        DropdownMenu<AiModel>(
          label: const Text('Model'),
          initialSelection: services.aiModel,
          width: 420,
          dropdownMenuEntries: [
            for (final model in AiModel.values)
              DropdownMenuEntry(value: model, label: model.label),
          ],
          onSelected: (model) {
            if (model != null) services.aiModel = model;
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Total biaya AI sejauh ini: '
          '${services.formatUsd(services.database.cvs.totalCostUsd())}. '
          'API key disimpan terenkripsi dengan akun Windows Anda.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

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
        final alerts = services.database.alerts.all();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(title: 'Pengaturan'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  _AiSettings(services: services),
                  const SectionTitle('Notifikasi'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Notifikasi desktop'),
                    subtitle: const Text(
                      'Lowongan baru yang cocok dengan pencarian tersimpan, '
                      'pengingat follow-up, dan interview dalam 24 jam. '
                      'Aplikasi memeriksa setiap 30 menit selama terbuka.',
                    ),
                    value: services.notificationsEnabled,
                    onChanged: (enabled) =>
                        services.notificationsEnabled = enabled,
                  ),
                  const SectionTitle('Pencarian tersimpan'),
                  if (alerts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Belum ada. Di halaman Lowongan, atur pencarian dan '
                        'filter, lalu pilih ikon penanda untuk menyimpannya.',
                      ),
                    ),
                  for (final alert in alerts)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.notifications_none),
                      title: Text(alert.name),
                      subtitle: Text(alert.filter.describe()),
                      trailing: IconButton(
                        tooltip: 'Hapus pencarian tersimpan',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          services.database.alerts.delete(alert.id);
                          services.dataChanged();
                        },
                      ),
                    ),
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
