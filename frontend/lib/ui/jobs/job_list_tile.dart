import 'package:flutter/material.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import 'review_panel.dart';

/// One row of the job list.
class JobListTile extends StatelessWidget {
  const JobListTile({
    super.key,
    required this.job,
    required this.sourceName,
    required this.selected,
    required this.onTap,
    required this.onToggleSaved,
  });

  final Job job;
  final String sourceName;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final publishedAt = job.publishedAt;
    final status = job.trackedStatus;
    return Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (job.warnings.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Tooltip(
                              message:
                                  'Perlu dicek: ${job.warnings.join('; ')}',
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 15,
                                color: scheme.error,
                              ),
                            ),
                          ),
                        if (job.regionFit == RegionFit.open)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Tooltip(
                              message: 'Terbuka untuk pelamar dari Indonesia',
                              child: Icon(
                                Icons.public,
                                size: 14,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            [
                              if (job.company.isNotEmpty) job.company,
                              if (job.location.isNotEmpty) job.location,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (job.matchScore != null) ...[
                          ScoreBadge(job.matchScore!),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            [
                              sourceName,
                              if (job.salary.isNotEmpty) job.salary,
                              if (publishedAt != null) timeAgo(publishedAt),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (status == null || status == ApplicationStatus.saved)
                IconButton(
                  tooltip: status == null
                      ? 'Simpan lowongan'
                      : 'Hapus dari simpanan',
                  icon: Icon(
                    status == null ? Icons.star_border : Icons.star,
                    color: status == null ? null : scheme.primary,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleSaved,
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: 6, right: 10, top: 2),
                  child: StatusLabel(status),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small pill naming where an application stands.
class StatusLabel extends StatelessWidget {
  const StatusLabel(this.status, {super.key});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      ApplicationStatus.rejected => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      ApplicationStatus.offer => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      _ => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground),
      ),
    );
  }
}
