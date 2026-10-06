import 'package:flutter/material.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import 'job_detail_view.dart';
import 'job_list_tile.dart';
import 'jobs_controller.dart';

/// The main screen: searchable job list on the left, the open job on the right.
class JobsPage extends StatefulWidget {
  const JobsPage({super.key, required this.repository});

  final JobRepository repository;

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  late final JobsController _controller = JobsController(widget.repository);
  final _searchField = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.load();
    _refresh(manual: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchField.dispose();
    super.dispose();
  }

  Future<void> _refresh({required bool manual}) async {
    final result = await _controller.refresh(manual: manual);
    if (!mounted) return;
    final message = _refreshMessage(result, manual: manual);
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// The automatic refresh at startup stays quiet unless something failed.
  String? _refreshMessage(RefreshResult result, {required bool manual}) {
    if (result.errors.isNotEmpty) {
      final failures = result.errors.entries
          .map((entry) => '${entry.key} (${entry.value})')
          .join(', ');
      return 'Gagal memperbarui: $failures';
    }
    if (!manual) return null;
    if (result.fetched.isEmpty) {
      return 'Semua sumber baru saja diperbarui. Coba lagi nanti.';
    }
    final total = result.fetched.values.fold(0, (sum, count) => sum + count);
    return 'Diperbarui: $total lowongan dari ${result.fetched.length} sumber.';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final lastUpdated = _controller.lastUpdated;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Pencari Kerja Remote'),
            actions: [
              if (lastUpdated != null)
                Center(
                  child: Text(
                    'Diperbarui ${timeAgo(lastUpdated)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(width: 8),
              if (_controller.refreshing)
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
                  onPressed: () => _refresh(manual: true),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              SizedBox(width: 440, child: _buildListPane(context)),
              const VerticalDivider(width: 1),
              Expanded(child: _buildDetailPane(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListPane(BuildContext context) {
    final jobs = _controller.jobs;
    final repository = widget.repository;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final source in repository.sources)
                FilterChip(
                  label: Text(source.name),
                  selected: !_controller.excludedSources.contains(source.id),
                  onSelected: (_) => _controller.toggleSource(source.id),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Text(
            '${jobs.length} lowongan',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: jobs.isEmpty
              ? _EmptyMessage(
                  _controller.refreshing
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
                      sourceName: repository.sourceName(job.sourceId),
                      selected: job.id == _controller.selected?.id,
                      onTap: () => _controller.select(job),
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
      return const _EmptyMessage('Pilih lowongan untuk melihat detailnya.');
    }
    return JobDetailView(
      // A new key per job resets the scroll position when the selection changes.
      key: ValueKey(job.id),
      job: job,
      descriptionHtml: _controller.selectedDescriptionHtml,
      sourceName: widget.repository.sourceName(job.sourceId),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
