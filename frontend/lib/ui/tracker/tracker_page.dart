import 'package:flutter/material.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import '../../app_services.dart';
import '../common.dart';
import 'application_dialog.dart';

/// The application tracker: one column per status, a card per tracked job.
class TrackerPage extends StatelessWidget {
  const TrackerPage({super.key, required this.services});

  final AppServices services;

  Future<void> _addManual(BuildContext context) async {
    final draft = await showDialog<ManualApplicationDraft>(
      context: context,
      builder: (context) => const ManualApplicationDialog(),
    );
    if (draft == null) return;
    services.database.applications.addManual(
      title: draft.title,
      company: draft.company,
      url: draft.url,
      status: draft.status,
      now: DateTime.now(),
    );
    services.dataChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services,
      builder: (context, _) {
        final applications = services.database.applications.all();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Lamaran',
              actions: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah manual'),
                  onPressed: () => _addManual(context),
                ),
              ],
            ),
            Expanded(
              child: applications.isEmpty
                  ? const EmptyMessage(
                      'Belum ada lowongan yang dilacak.\n'
                      'Simpan lowongan dengan tombol bintang, atau tambahkan '
                      'lamaran dari situs lain lewat "Tambah manual".',
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final status in ApplicationStatus.values)
                            Expanded(
                              child: _StatusColumn(
                                status: status,
                                applications: [
                                  for (final application in applications)
                                    if (application.status == status)
                                      application,
                                ],
                                services: services,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusColumn extends StatelessWidget {
  const _StatusColumn({
    required this.status,
    required this.applications,
    required this.services,
  });

  final ApplicationStatus status;
  final List<Application> applications;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              '${status.label} · ${applications.length}',
              style: theme.textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                for (final application in applications)
                  _ApplicationCard(
                    application: application,
                    services: services,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.services});

  final Application application;
  final AppServices services;

  void _move(ApplicationStatus status) {
    services.database.applications.setStatus(
      application.jobId,
      status,
      now: DateTime.now(),
    );
    services.dataChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final interviewAt = application.interviewAt;
    final appliedAt = application.appliedAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) =>
              ApplicationDialog(application: application, services: services),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (application.company.isNotEmpty)
                      Text(
                        application.company,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      appliedAt == null
                          ? 'Disimpan ${timeAgo(application.createdAt)}'
                          : 'Dilamar ${timeAgo(appliedAt)}',
                      style: muted,
                    ),
                    if (interviewAt != null)
                      Text(
                        'Interview ${shortDateTime(interviewAt)}',
                        style: muted,
                      ),
                    if (application.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        application.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<ApplicationStatus>(
                tooltip: 'Pindahkan',
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: _move,
                itemBuilder: (context) => [
                  for (final status in ApplicationStatus.values)
                    if (status != application.status)
                      PopupMenuItem(
                        value: status,
                        child: Text('Pindah ke ${status.label}'),
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
