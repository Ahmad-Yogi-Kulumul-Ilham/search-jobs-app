import 'package:flutter/material.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import '../../app_services.dart';
import '../common.dart';

/// The AI provider, its API key, and the model used for CV reviews and
/// drafts.
class _AiSettings extends StatefulWidget {
  const _AiSettings({required this.services});

  final AppServices services;

  @override
  State<_AiSettings> createState() => _AiSettingsState();
}

class _AiSettingsState extends State<_AiSettings> {
  final _key = TextEditingController();
  late final TextEditingController _openRouterModel;

  /// The company name as it appears on its key page.
  static const _company = {
    AiProvider.anthropic: 'Anthropic',
    AiProvider.openai: 'OpenAI',
    AiProvider.gemini: 'Google Gemini',
    AiProvider.openrouter: 'OpenRouter',
  };

  @override
  void initState() {
    super.initState();
    _openRouterModel = TextEditingController(
      text: widget.services.openRouterModel,
    );
  }

  @override
  void dispose() {
    _key.dispose();
    _openRouterModel.dispose();
    super.dispose();
  }

  void _saveKey(AiProvider provider) {
    final key = _key.text.trim();
    if (key.isEmpty) return;
    if (!key.startsWith(provider.keyPrefix)) {
      showMessage(
        context,
        'API key ${_company[provider]} biasanya diawali '
        '"${provider.keyPrefix}". Periksa lagi.',
      );
      return;
    }
    widget.services.setApiKey(key, provider: provider);
    _key.clear();
    showMessage(context, 'API key tersimpan dan terenkripsi.');
  }

  void _saveOpenRouterModel() {
    final id = _openRouterModel.text.trim();
    if (!id.contains('/')) {
      showMessage(
        context,
        'ID model OpenRouter berbentuk penyedia/nama, misalnya '
        'deepseek/deepseek-chat.',
      );
      return;
    }
    widget.services.openRouterModel = id;
    showMessage(context, 'Model $id dipakai.');
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final model = services.aiModel;
    final provider = model.provider;
    final key = services.apiKeyFor(provider);
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('AI'),
        const Text(
          'Dipakai untuk review CV, cover letter, dan draf jawaban. Pilih '
          'penyedia, lalu masukkan API key-nya. API key berbeda dari '
          'langganan seperti ChatGPT Plus, Gemini Advanced, atau Claude Pro: '
          'biayanya dihitung per pemakaian.',
        ),
        const SizedBox(height: 14),
        DropdownMenu<AiProvider>(
          label: const Text('Penyedia'),
          initialSelection: provider,
          width: 420,
          dropdownMenuEntries: [
            for (final option in AiProvider.values)
              DropdownMenuEntry(value: option, label: option.label),
          ],
          onSelected: (option) {
            if (option != null && option != provider) {
              services.aiModel = option.defaultModel;
            }
          },
        ),
        const SizedBox(height: 14),
        if (key != null)
          Row(
            children: [
              const Icon(Icons.key, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'API key tersimpan: ${provider.keyPrefix}…'
                  '${key.substring(key.length - 4)}',
                ),
              ),
              TextButton(
                onPressed: () => services.setApiKey(null, provider: provider),
                child: const Text('Hapus'),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('key-$provider'),
                  controller: _key,
                  obscureText: true,
                  onSubmitted: (_) => _saveKey(provider),
                  decoration: InputDecoration(
                    labelText: 'API key ${_company[provider]}',
                    hintText: '${provider.keyPrefix}…',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () => _saveKey(provider),
                child: const Text('Simpan'),
              ),
            ],
          ),
        const SizedBox(height: 6),
        Text(
          'Buat API key dan isi saldo di ${provider.consoleUrl}.'
          '${provider == AiProvider.gemini ? ' Gemini punya kuota gratis, '
                    'tetapi Google dapat memakai data dari kuota gratis '
                    'untuk meningkatkan layanannya.' : ''}',
          style: small,
        ),
        const SizedBox(height: 14),
        if (provider == AiProvider.openrouter)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _openRouterModel,
                  onSubmitted: (_) => _saveOpenRouterModel(),
                  decoration: const InputDecoration(
                    labelText: 'ID model OpenRouter',
                    hintText: 'contoh: deepseek/deepseek-chat',
                    helperText:
                        'Lihat daftarnya di openrouter.ai/models. Biaya '
                        'diambil dari tagihan OpenRouter.',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonal(
                onPressed: _saveOpenRouterModel,
                child: const Text('Pakai model'),
              ),
            ],
          )
        else
          DropdownMenu<AiModel>(
            // A new provider starts a fresh menu on its default model.
            key: ValueKey(provider),
            label: const Text('Model'),
            initialSelection: model,
            width: 420,
            dropdownMenuEntries: [
              for (final option in provider.models)
                DropdownMenuEntry(value: option, label: option.label),
            ],
            onSelected: (option) {
              if (option != null) services.aiModel = option;
            },
          ),
        const SizedBox(height: 8),
        Text(
          'Setiap review mengirim CV dan teks lowongan ke '
          '${provider.shortName}. Total biaya AI sejauh ini: '
          '${services.formatUsd(services.database.cvs.totalCostUsd())}. '
          'API key disimpan terenkripsi dengan akun Windows Anda.',
          style: small,
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
