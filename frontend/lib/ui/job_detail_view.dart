import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full view of one job, with a button that opens the original posting.
class JobDetailView extends StatelessWidget {
  const JobDetailView({
    super.key,
    required this.job,
    required this.descriptionHtml,
    required this.sourceName,
  });

  final Job job;
  final String descriptionHtml;
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final publishedAt = job.publishedAt;
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title, style: theme.textTheme.headlineSmall),
                if (job.company.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(job.company, style: theme.textTheme.titleMedium),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    if (job.location.isNotEmpty)
                      _Fact(Icons.public, job.location),
                    if (job.jobType.isNotEmpty)
                      _Fact(Icons.work_outline, job.jobType),
                    if (job.salary.isNotEmpty)
                      _Fact(Icons.payments_outlined, job.salary),
                    if (job.category.isNotEmpty)
                      _Fact(Icons.category_outlined, job.category),
                    if (publishedAt != null)
                      _Fact(Icons.schedule, timeAgo(publishedAt)),
                  ],
                ),
                if (job.tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in job.tags)
                        Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text('Lamar di $sourceName'),
                      onPressed: () => _openInBrowser(context, job.url),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Sumber: $sourceName',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 18),
                if (descriptionHtml.isEmpty)
                  const Text('Deskripsi tidak tersedia. Buka halaman aslinya.')
                else
                  HtmlWidget(
                    descriptionHtml,
                    onTapUrl: (url) {
                      _openInBrowser(context, url);
                      return true;
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

/// Opens a link from a posting in the default browser. Links come from remote
/// data, so anything that is not a web address is refused.
Future<void> _openInBrowser(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final isWebLink = uri != null && (uri.isScheme('https') || uri.isScheme('http'));
  final opened =
      isWebLink && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Tautan tidak bisa dibuka.')));
}
