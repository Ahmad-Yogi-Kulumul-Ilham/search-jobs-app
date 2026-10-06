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
            onChanged: _controller.setFilter,
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
