import 'package:flutter/material.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

/// One row of the job list.
class JobListTile extends StatelessWidget {
  const JobListTile({
    super.key,
    required this.job,
    required this.sourceName,
    required this.selected,
    required this.onTap,
  });

  final Job job;
  final String sourceName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final publishedAt = job.publishedAt;
    return Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              Text(
                [
                  if (job.company.isNotEmpty) job.company,
                  if (job.location.isNotEmpty) job.location,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                [
                  sourceName,
                  if (job.salary.isNotEmpty) job.salary,
                  if (publishedAt != null) timeAgo(publishedAt),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
