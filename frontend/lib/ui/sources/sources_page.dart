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

  Future<void> _discover(BuildContext context) async {
    final before = services.database.sources.custom().length;
    await showDialog<void>(
      context: context,
      builder: (context) => _DiscoverDialog(services: services),
    );
    final added = services.database.sources.custom().length - before;
    if (added <= 0 || !context.mounted) return;
    showMessage(context, '$added sumber ditambahkan. Mengambil lowongannya…');
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
                OutlinedButton.icon(
                  icon: const Icon(Icons.explore_outlined, size: 18),
                  label: const Text('Temukan sumber'),
                  onPressed: () => _discover(context),
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
                        'Belum ada. Pilih dari sumber yang disarankan lewat '
                        '"Temukan sumber", atau tambahkan sendiri feed RSS '
                        'situs lowongan atau halaman karier perusahaan incaran '
                        'yang memakai Greenhouse, Lever, atau Ashby.',
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
    final result = await _checkAndAdd(
      widget.services,
      kind: parsed.kind,
      name: name,
      value: parsed.value,
    );
    if (!mounted) return;
    final added = result.added;
    if (added == null) {
      setState(() {
        _checking = false;
        _error = result.error;
      });
      return;
    }
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

/// Fetches a source once, so a wrong link or a board that has gone away is
/// caught before it is stored, then stores it. Returns the stored source, or
/// the reason it was not added.
Future<({CustomSource? added, String? error})> _checkAndAdd(
  AppServices services, {
  required CustomSourceKind kind,
  required String name,
  required String value,
}) async {
  try {
    await services.repository.probe(
      sourceFor(CustomSource(id: 0, kind: kind, name: name, value: value)),
    );
  } on Exception catch (error) {
    return (
      added: null,
      error: 'Sumber tidak bisa dibaca: ${describeFetchError(error)}',
    );
  }
  final added = services.database.sources.addCustom(
    kind: kind,
    name: name,
    value: value,
  );
  if (added == null) {
    return (added: null, error: 'Sumber ini sudah pernah ditambahkan.');
  }
  services.dataChanged();
  return (added: added, error: null);
}

/// One row in the discovery dialog: a found source or a hand-picked one.
class _Option {
  _Option.found(DiscoveredSource this.found)
    : suggestion = null,
      kind = found.kind,
      value = found.value,
      name = found.name;

  _Option.suggested(SuggestedSource this.suggestion)
    : found = null,
      kind = suggestion.kind,
      value = suggestion.value,
      name = suggestion.name;

  final DiscoveredSource? found;
  final SuggestedSource? suggestion;
  final CustomSourceKind kind;
  final String value;
  final String name;

  String get key => '${kind.name}:${value.toLowerCase()}';

  bool matches(CustomSource source) =>
      source.kind == kind && source.value.toLowerCase() == value.toLowerCase();

  /// What the row says about the source, for display and for searching.
  List<String> get details {
    final found = this.found;
    if (found == null) return [suggestion!.description];
    final jobs = found.kind == CustomSourceKind.rss
        ? '${found.remoteJobs} lowongan'
        : '${found.remoteJobs} lowongan remote'
              '${found.openJobs > 0 ? ', ${found.openJobs} bisa dari Indonesia' : ''}';
    return [
      jobs,
      switch (found.origin) {
        DiscoveryOrigin.company when found.verified =>
          'Ditemukan dari lowongan perusahaan ini yang sudah masuk.',
        DiscoveryOrigin.company =>
          'Namanya sama dengan perusahaan di lowongan, tapi lowongannya '
              'berbeda: bisa jadi perusahaan lain.',
        DiscoveryOrigin.link => 'Ditautkan dari lowongan yang sudah masuk.',
        DiscoveryOrigin.ai =>
          found.note.isEmpty ? 'Saran AI.' : 'Saran AI: ${found.note}',
      },
    ];
  }
}

enum _Search { jobs, ai }

/// Hand-picked sources plus sources found on request, from the companies in
/// stored jobs or by an AI web search. The user ticks the ones to add.
class _DiscoverDialog extends StatefulWidget {
  const _DiscoverDialog({required this.services});

  final AppServices services;

  @override
  State<_DiscoverDialog> createState() => _DiscoverDialogState();
}

class _DiscoverDialogState extends State<_DiscoverDialog> {
  static const _seenKey = 'discovery_seen_at';

  final _query = TextEditingController();
  final _selected = <String>{};
  final _errors = <String, String>{};
  late List<DiscoveredSource> _found;

  /// Found by a search in this dialog. These always show: the search text
  /// doubles as the AI's focus, and its finds need not contain the words.
  final _fresh = <String>{};

  /// Sources found after this were not seen before and are marked new.
  late final DateTime _seenAt;
  _Search? _searching;
  (int, int)? _progress;
  String? _status;
  bool _statusIsError = false;
  bool _adding = false;

  AppServices get _services => widget.services;

  @override
  void initState() {
    super.initState();
    final seen = int.tryParse(_services.database.settings.get(_seenKey) ?? '');
    _seenAt = DateTime.fromMillisecondsSinceEpoch(seen ?? 0);
    _reload();
  }

  @override
  void dispose() {
    _services.database.settings.set(
      _seenKey,
      '${_services.now().millisecondsSinceEpoch}',
    );
    _query.dispose();
    super.dispose();
  }

  bool _isNew(DiscoveredSource source) => source.foundAt.isAfter(_seenAt);

  /// Reloads the found sources and ticks the new ones that look best: the
  /// right company, with jobs open to Indonesia.
  void _reload() {
    _found = _services.database.discovery.all();
    for (final source in _found) {
      if (_isNew(source) && source.verified && source.openJobs > 0) {
        _selected.add(_Option.found(source).key);
      }
    }
  }

  Future<void> _search(_Search how) async {
    setState(() {
      _searching = how;
      _progress = null;
      _status = null;
      _statusIsError = false;
    });
    final discovery = _services.repository.discovery;
    void remember(DiscoveryResult result) =>
        _fresh.addAll(result.found.map((source) => _Option.found(source).key));
    try {
      if (how == _Search.jobs) {
        final result = await discovery.fromJobs(
          onProgress: (done, total) {
            if (mounted) setState(() => _progress = (done, total));
          },
        );
        remember(result);
        _status = [
          if (result.checkedCompanies == 0 && result.found.isEmpty)
            'Semua perusahaan di lowongan sudah diperiksa. Perbarui lowongan '
                'untuk menemukan perusahaan baru, atau coba "Cari dengan AI".'
          else
            '${result.found.length} sumber baru dari '
                '${result.checkedCompanies} perusahaan yang diperiksa.',
          if (result.remainingCompanies > 0)
            'Masih ada ${result.remainingCompanies} perusahaan lagi: klik '
                '"Cari dari lowongan" untuk melanjutkan.',
        ].join(' ');
      } else {
        final result = await discovery.withAi(
          _services.aiClient()!,
          focus: _query.text,
        );
        final usage = result.usage!;
        _services.recordSpend(usage);
        remember(result);
        _status =
            'AI menyarankan ${result.suggested} sumber: '
            '${result.found.length} baru dan bisa dibaca'
            '${result.unreadable > 0 ? ', ${result.unreadable} tidak bisa '
                      'dibaca dan dilewati' : ''}. Biaya '
            '${_services.formatUsd(usage.costUsd)}.';
      }
    } on AiException catch (error) {
      _status = error.message;
      _statusIsError = true;
    }
    if (!mounted) return;
    setState(() {
      _searching = null;
      _reload();
    });
  }

  void _dismiss(DiscoveredSource source) {
    _services.database.discovery.dismiss(source.kind, source.value);
    setState(() {
      _selected.remove(_Option.found(source).key);
      _found.remove(source);
    });
  }

  Future<void> _addSelected(List<_Option> options) async {
    setState(() {
      _adding = true;
      _errors.clear();
    });
    await Future.wait([
      for (final option in options)
        if (_selected.contains(option.key))
          () async {
            final String? error;
            if (option.found != null) {
              // Found sources were fetched when found; no need to again.
              error =
                  _services.database.sources.addCustom(
                        kind: option.kind,
                        name: option.name,
                        value: option.value,
                      ) ==
                      null
                  ? 'Sumber ini sudah pernah ditambahkan.'
                  : null;
            } else {
              error = (await _checkAndAdd(
                _services,
                kind: option.kind,
                name: option.name,
                value: option.value,
              )).error;
            }
            if (error != null) {
              _errors[option.key] = error;
            } else {
              _selected.remove(option.key);
            }
          }(),
    ]);
    _services.dataChanged();
    if (mounted) setState(() => _adding = false);
  }

  bool _shown(_Option option, String query) =>
      query.isEmpty ||
      [
        option.name,
        option.kind.label,
        ...option.details,
        ?option.suggestion?.group.label,
      ].any((text) => text.toLowerCase().contains(query));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final custom = _services.database.sources.custom();
    final query = _query.text.trim().toLowerCase();
    final found = [
      for (final source in _found)
        if (_Option.found(source) case final option
            when _fresh.contains(option.key) || _shown(option, query))
          option,
    ];
    final groups = [
      for (final group in SuggestionGroup.values)
        (
          group: group,
          items: [
            for (final suggestion in suggestedSources)
              if (suggestion.group == group)
                if (_Option.suggested(suggestion) case final option
                    when _shown(option, query))
                  option,
          ],
        ),
    ].where((entry) => entry.items.isNotEmpty).toList();
    final all = [...found, for (final entry in groups) ...entry.items];
    final picked = all
        .where((o) => _selected.contains(o.key) && !custom.any(o.matches))
        .length;
    final busy = _searching != null || _adding;
    final aiReady = _services.aiReady;

    Widget tile(_Option option) {
      final added = custom.any(option.matches);
      final source = option.found;
      final title = Row(
        children: [
          Flexible(child: Text(option.name)),
          if (source != null && _isNew(source)) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Baru',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      );
      final subtitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${option.kind.label} · ${option.details.first}'),
          for (final line in option.details.skip(1)) Text(line, style: muted),
          if (_errors[option.key] case final error?)
            Text(error, style: TextStyle(color: theme.colorScheme.error)),
        ],
      );
      if (added) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.check, color: theme.colorScheme.primary),
          title: title,
          subtitle: subtitle,
          trailing: Text(
            'Ditambahkan',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        );
      }
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _selected.contains(option.key),
        onChanged: _adding
            ? null
            : (checked) => setState(
                () => checked == true
                    ? _selected.add(option.key)
                    : _selected.remove(option.key),
              ),
        title: title,
        subtitle: subtitle,
        secondary: source == null
            ? null
            : IconButton(
                tooltip: 'Sembunyikan saran ini',
                icon: const Icon(Icons.close, size: 18),
                onPressed: _adding ? null : () => _dismiss(source),
              ),
      );
    }

    return AlertDialog(
      title: const Text('Temukan sumber'),
      content: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText:
                    'Cari nama atau bidang, misalnya kripto, desain, APAC '
                    '(juga jadi fokus untuk AI)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.travel_explore, size: 18),
                  label: const Text('Cari dari lowongan'),
                  onPressed: busy ? null : () => _search(_Search.jobs),
                ),
                Tooltip(
                  message: aiReady
                      ? 'Mencari di web dengan ${_services.aiModel.provider.shortName}. '
                            'Ada biaya kecil per pencarian.'
                      : 'Atur penyedia AI dan API key di Pengaturan dulu.',
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Cari dengan AI'),
                    onPressed: busy || !aiReady
                        ? null
                        : () => _search(_Search.ai),
                  ),
                ),
                if (_searching != null) ...[
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  Text(switch ((_searching, _progress)) {
                    (_Search.jobs, (final done, final total)) =>
                      'Memeriksa $done dari $total…',
                    (_Search.jobs, _) => 'Memeriksa perusahaan…',
                    _ =>
                      '${_services.aiModel.provider.shortName} sedang '
                          'mencari di web. Biasanya butuh satu sampai dua '
                          'menit.',
                  }, style: muted),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _status ??
                  'Cari dari lowongan: gratis, memeriksa apakah perusahaan di '
                      'lowongan yang sudah masuk punya halaman karier di '
                      'Greenhouse, Lever, atau Ashby. Cari dengan AI: mencari '
                      'situs dan perusahaan baru di web. Setiap temuan dicek '
                      'dulu sebelum ditampilkan.',
              style: _statusIsError
                  ? theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    )
                  : muted,
            ),
            Expanded(
              child: all.isEmpty
                  ? const EmptyMessage('Tidak ada saran yang cocok.')
                  : ListView(
                      children: [
                        if (found.isNotEmpty) ...[
                          const SectionTitle('Hasil penemuan'),
                          for (final option in found) tile(option),
                        ],
                        for (final entry in groups) ...[
                          SectionTitle(entry.group.label),
                          Text(entry.group.hint, style: muted),
                          for (final option in entry.items) tile(option),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _adding ? null : () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        FilledButton(
          onPressed: picked == 0 || busy ? null : () => _addSelected(all),
          child: Text(
            _adding ? 'Menambahkan…' : 'Tambah yang dicentang ($picked)',
          ),
        ),
      ],
    );
  }
}
