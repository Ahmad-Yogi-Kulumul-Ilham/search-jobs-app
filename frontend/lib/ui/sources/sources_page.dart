import 'package:flutter/material.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import '../../app_services.dart';
import '../common.dart';

/// Where jobs come from: switches for the built-in sites, and the feeds and
/// company boards the user added.
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key, required this.services});

  final AppServices services;

  Future<void> _refresh(BuildContext context) async {
    final result = await services.refresh(manual: true);
    if (!context.mounted) return;
    final message = refreshMessage(result, manual: true);
    if (message != null) showMessage(context, message);
  }

  Future<void> _add(BuildContext context) async {
    final added = await showDialog<CustomSource>(
      context: context,
      builder: (context) => _AddSourceDialog(services: services),
    );
    if (added == null || !context.mounted) return;
    showMessage(context, '${added.name} ditambahkan. Mengambil lowongannya…');
    await _refresh(context);
  }

  Future<void> _delete(BuildContext context, CustomSource source) async {
    final sure = await confirm(
      context,
      title: 'Hapus ${source.name}?',
      message:
          'Lowongan dari sumber ini ikut dihapus, kecuali yang sudah ada di '
          'pelacak lamaran.',
      confirmLabel: 'Hapus',
    );
    if (!sure) return;
    services.database.sources.deleteCustom(source.id);
    services.database.jobs.forgetSource(source.sourceId);
    services.dataChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services,
      builder: (context, _) {
        final store = services.database.sources;
        final disabled = store.disabledBuiltIns();
        final custom = store.custom();
        final counts = services.database.jobs.countBySource();

        String status(String sourceId) {
          final fetchedAt = services.database.jobs.lastFetchedAt(sourceId);
          return [
            '${counts[sourceId] ?? 0} lowongan',
            fetchedAt == null
                ? 'belum pernah diambil'
                : 'diperbarui ${timeAgo(fetchedAt)}',
          ].join(' · ');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Sumber lowongan',
              actions: [
                if (services.refreshing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Perbarui'),
                    onPressed: () => _refresh(context),
                  ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah sumber'),
                  onPressed: () => _add(context),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  const SectionTitle('Situs lowongan bawaan'),
                  for (final source in services.registry.builtIn)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(source.name),
                      subtitle: Text(status(source.id)),
                      value: !disabled.contains(source.id),
                      onChanged: (enabled) {
                        store.setBuiltInEnabled(source.id, enabled);
                        services.dataChanged();
                      },
                    ),
                  const SectionTitle('Sumber tambahan'),
                  if (custom.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Belum ada. Anda bisa menambahkan feed RSS situs '
                        'lowongan, atau halaman karier perusahaan incaran yang '
                        'memakai Greenhouse, Lever, atau Ashby.',
                      ),
                    ),
                  for (final source in custom)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(source.name),
                      subtitle: Text(
                        '${source.kind.label} · ${status(source.sourceId)}',
                      ),
                      secondary: IconButton(
                        tooltip: 'Hapus sumber',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, source),
                      ),
                      value: source.enabled,
                      onChanged: (enabled) {
                        store.setCustomEnabled(source.id, enabled);
                        services.dataChanged();
                      },
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

/// Takes a pasted link, checks that it really lists jobs, and stores it.
class _AddSourceDialog extends StatefulWidget {
  const _AddSourceDialog({required this.services});

  final AppServices services;

  @override
  State<_AddSourceDialog> createState() => _AddSourceDialogState();
}

class _AddSourceDialogState extends State<_AddSourceDialog> {
  final _link = TextEditingController();
  final _name = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _link.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final parsed = parseSourceInput(_link.text);
    if (parsed == null) {
      setState(() => _error = 'Tempel alamat lengkap, misalnya https://…');
      return;
    }
    final name = _name.text.trim().isEmpty
        ? parsed.suggestedName
        : _name.text.trim();
    setState(() {
      _checking = true;
      _error = null;
    });
    // Fetch once before storing, so a wrong link is caught right here.
    try {
      await widget.services.repository.probe(
        sourceFor(
          CustomSource(
            id: 0,
            kind: parsed.kind,
            name: name,
            value: parsed.value,
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Sumber tidak bisa dibaca: ${describeFetchError(error)}';
      });
      return;
    }
    if (!mounted) return;
    final added = widget.services.database.sources.addCustom(
      kind: parsed.kind,
      name: name,
      value: parsed.value,
    );
    if (added == null) {
      setState(() {
        _checking = false;
        _error = 'Sumber ini sudah pernah ditambahkan.';
      });
      return;
    }
    widget.services.dataChanged();
    Navigator.pop(context, added);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = parseSourceInput(_link.text);
    return AlertDialog(
      title: const Text('Tambah sumber'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tempel salah satu dari:\n'
              '• alamat feed RSS situs lowongan, atau\n'
              '• halaman karier perusahaan di Greenhouse, Lever, atau Ashby, '
              'misalnya https://jobs.ashbyhq.com/linear\n\n'
              'Dari halaman karier perusahaan, hanya lowongan remote yang '
              'diambil.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _link,
              autofocus: true,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Alamat',
                border: const OutlineInputBorder(),
                errorText: _error,
                errorMaxLines: 3,
                helperText: parsed == null
                    ? null
                    : 'Terdeteksi: ${parsed.kind.label}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                labelText: 'Nama (opsional)',
                hintText: parsed?.suggestedName,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _checking ? null : _submit,
          child: Text(_checking ? 'Memeriksa…' : 'Periksa dan tambah'),
        ),
      ],
    );
  }
}
