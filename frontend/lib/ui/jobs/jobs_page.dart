import 'package:flutter/material.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import '../../app_services.dart';
import '../common.dart';
import 'job_detail_view.dart';
import 'job_list_tile.dart';
import 'jobs_controller.dart';

/// The jobs screen: searchable, filterable list on the left, the open job on
/// the right.
class JobsPage extends StatefulWidget {
  const JobsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  late final JobsController _controller = JobsController(widget.services);
  final _searchField = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _searchField.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final result = await widget.services.refresh(manual: true);
    if (!mounted) return;
    final message = refreshMessage(result, manual: true);
    if (message != null) showMessage(context, message);
  }

  void _applyAlert(JobAlert alert) {
    _searchField.text = alert.filter.query;
    _controller.setFilter(alert.filter);
  }

  Future<void> _saveAlert() async {
    final filter = _controller.filter;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _AlertNameDialog(filter: filter),
    );
    if (name == null || !mounted) return;
    widget.services.database.alerts.add(name, filter);
    widget.services.dataChanged();
    showMessage(
      context,
      'Tersimpan. Anda akan diberi tahu saat ada lowongan baru yang cocok.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Row(
        children: [
          SizedBox(width: 440, child: _buildListPane(context)),
          const VerticalDivider(width: 1),
          Expanded(child: _buildDetailPane(context)),
        ],
      ),
    );
  }

  Widget _buildListPane(BuildContext context) {
    final services = widget.services;
    final jobs = _controller.jobs;
    final lastUpdated = services.database.jobs.latestFetch();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchField,
                  onChanged: _controller.setQuery,
                  decoration: InputDecoration(
                    hintText: 'Cari posisi, perusahaan, atau keahlian',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchField.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchField.clear();
                              _controller.setQuery('');
                            },
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              _SavedSearchMenu(
                alerts: services.database.alerts.all(),
                canSave:
                    _controller.filter.query.trim().isNotEmpty ||
                    _controller.filter.activeCount > 0,
                onApply: _applyAlert,
                onSave: _saveAlert,
              ),
              if (services.refreshing)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Perbarui lowongan',
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _FilterBar(
            filter: _controller.filter,
            sources: services.registry.active(),
            // The bar was built before the latest keystrokes reached the
            // list, so keep the query the controller has now.
            onChanged: (filter) => _controller.setFilter(
              filter.copyWith(query: _controller.filter.query),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Text(
            [
              '${jobs.length} lowongan',
              if (lastUpdated != null) 'diperbarui ${timeAgo(lastUpdated)}',
            ].join(' · '),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: jobs.isEmpty
              ? EmptyMessage(
                  services.refreshing
                      ? 'Mengambil lowongan…'
                      : 'Tidak ada lowongan yang cocok.',
                )
              : ListView.separated(
                  itemCount: jobs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return JobListTile(
                      job: job,
                      sourceName: services.registry.nameOf(job.sourceId),
                      selected: job.id == _controller.selected?.id,
                      onTap: () => _controller.select(job),
                      onToggleSaved: () => _controller.toggleSaved(job),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetailPane(BuildContext context) {
    final job = _controller.selected;
    if (job == null) {
      return const EmptyMessage('Pilih lowongan untuk melihat detailnya.');
    }
    return JobDetailView(
      // A new key per job resets the scroll position when the selection changes.
      key: ValueKey(job.id),
      job: job,
      descriptionHtml: _controller.selectedDescriptionHtml,
      sourceName: widget.services.registry.nameOf(job.sourceId),
      rates: widget.services.rates,
      controller: _controller,
    );
  }
}

/// Saved searches: apply one, or save the current search as a new one.
class _SavedSearchMenu extends StatelessWidget {
  const _SavedSearchMenu({
    required this.alerts,
    required this.canSave,
    required this.onApply,
    required this.onSave,
  });

  final List<JobAlert> alerts;
  final bool canSave;
  final ValueChanged<JobAlert> onApply;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final alert in alerts)
          MenuItemButton(
            leadingIcon: const Icon(Icons.notifications_none, size: 18),
            onPressed: () => onApply(alert),
            child: Text(alert.name),
          ),
        if (alerts.isNotEmpty) const Divider(height: 8),
        MenuItemButton(
          leadingIcon: const Icon(Icons.add_alert_outlined, size: 18),
          onPressed: canSave ? onSave : null,
          child: Text(
            canSave
                ? 'Simpan pencarian ini sebagai peringatan…'
                : 'Isi pencarian atau filter dulu untuk menyimpannya',
          ),
        ),
      ],
      builder: (context, menu, _) => IconButton(
        tooltip: 'Pencarian tersimpan',
        icon: Icon(alerts.isEmpty ? Icons.bookmark_border : Icons.bookmark),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

class _AlertNameDialog extends StatefulWidget {
  const _AlertNameDialog({required this.filter});

  final JobFilter filter;

  @override
  State<_AlertNameDialog> createState() => _AlertNameDialogState();
}

class _AlertNameDialogState extends State<_AlertNameDialog> {
  late final _name = TextEditingController(
    text: widget.filter.query.trim().isNotEmpty
        ? widget.filter.query.trim()
        : widget.filter.describe(),
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Simpan pencarian'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter: ${widget.filter.describe()}'),
            const SizedBox(height: 6),
            const Text(
              'Setelah lowongan diperbarui, Anda akan diberi tahu jika ada '
              'lowongan baru yang cocok.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Nama',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}

/// Quick filter chips plus menus for job type and source.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.sources,
    required this.onChanged,
  });

  final JobFilter filter;
  final List<JobSource> sources;
  final ValueChanged<JobFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    Set<String> toggled(Set<String> values, String value) =>
        values.contains(value)
        ? ({...values}..remove(value))
        : {...values, value};

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          label: const Text('Bisa dari Indonesia'),
          tooltip:
              'Hanya lowongan yang lokasinya seluruh dunia atau mencakup '
              'Asia/Indonesia',
          selected: filter.openToIndonesiaOnly,
          onSelected: (value) =>
              onChanged(filter.copyWith(openToIndonesiaOnly: value)),
          visualDensity: VisualDensity.compact,
        ),
        FilterChip(
          label: const Text('Ada gaji'),
          selected: filter.withSalaryOnly,
          onSelected: (value) =>
              onChanged(filter.copyWith(withSalaryOnly: value)),
          visualDensity: VisualDensity.compact,
        ),
        _MenuChip(
          label: filter.jobTypes.isEmpty
              ? 'Jenis kerja'
              : 'Jenis kerja (${filter.jobTypes.length})',
          active: filter.jobTypes.isNotEmpty,
          items: [
            for (final type in jobTypeLabels)
              CheckboxMenuButton(
                value: filter.jobTypes.contains(type),
                closeOnActivate: false,
                onChanged: (_) => onChanged(
                  filter.copyWith(jobTypes: toggled(filter.jobTypes, type)),
                ),
                child: Text(type),
              ),
          ],
        ),
        _MenuChip(
          label: filter.excludedSources.isEmpty
              ? 'Sumber'
              : 'Sumber (${sources.length - filter.excludedSources.length})',
          active: filter.excludedSources.isNotEmpty,
          items: [
            for (final source in sources)
              CheckboxMenuButton(
                value: !filter.excludedSources.contains(source.id),
                closeOnActivate: false,
                onChanged: (_) => onChanged(
                  filter.copyWith(
                    excludedSources: toggled(filter.excludedSources, source.id),
                  ),
                ),
                child: Text(source.name),
              ),
          ],
        ),
        if (filter.activeCount > 0)
          TextButton(
            onPressed: () => onChanged(JobFilter(query: filter.query)),
            child: const Text('Reset'),
          ),
      ],
    );
  }
}

/// A chip that opens a menu of checkboxes.
class _MenuChip extends StatelessWidget {
  const _MenuChip({
    required this.label,
    required this.active,
    required this.items,
  });

  final String label;
  final bool active;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: items,
      builder: (context, menu, _) => FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(label), const Icon(Icons.arrow_drop_down, size: 18)],
        ),
        selected: active,
        showCheckmark: false,
        onSelected: (_) => menu.isOpen ? menu.close() : menu.open(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
