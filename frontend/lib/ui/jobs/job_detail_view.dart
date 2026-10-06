import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import '../../app_services.dart';
import '../common.dart';
import 'jobs_controller.dart';
import 'review_panel.dart';

/// Full view of one job, with the actions the user can take on it.
class JobDetailView extends StatelessWidget {
  const JobDetailView({
    super.key,
    required this.job,
    required this.descriptionHtml,
    required this.sourceName,
    required this.rates,
    required this.controller,
    required this.services,
  });

  final AppServices services;
  final Job job;
  final String descriptionHtml;
  final String sourceName;
  final ExchangeRates? rates;
  final JobsController controller;

  Future<void> _apply(BuildContext context) async {
    final opened = await openInBrowser(context, job.url);
    if (!opened || !context.mounted) return;
    final status = job.trackedStatus;
    if (status != null && status != ApplicationStatus.saved) return;
    showMessage(
      context,
      'Sudah mengirim lamaran?',
      action: SnackBarAction(
        label: 'Tandai dilamar',
        onPressed: () => controller.setStatus(job, ApplicationStatus.applied),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final publishedAt = job.publishedAt;
    final salaryRange = job.salaryRange;
    final rupiah = salaryRange == null || rates == null
        ? null
        : rupiahPerMonth(salaryRange, rates!);
    final hours = job.regionFit == RegionFit.restricted
        ? estimateWorkHoursWib(job.location)
        : const <WorkHoursEstimate>[];
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
                if (job.warnings.isNotEmpty) ...[
                  _WarningBanner(job.warnings),
                  const SizedBox(height: 16),
                ],
                Text(job.title, style: theme.textTheme.headlineSmall),
                if (job.company.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(job.company, style: theme.textTheme.titleMedium),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (job.location.isNotEmpty)
                      _Fact(Icons.place_outlined, job.location),
                    _RegionLabel(job.regionFit),
                    if (job.jobType.isNotEmpty)
                      _Fact(Icons.work_outline, job.jobType),
                    if (job.salary.isNotEmpty)
                      _Fact(
                        Icons.payments_outlined,
                        [job.salary, ?rupiah].join('  '),
                      ),
                    if (job.category.isNotEmpty)
                      _Fact(Icons.category_outlined, job.category),
                    if (publishedAt != null)
                      _Fact(Icons.schedule, timeAgo(publishedAt)),
                  ],
                ),
                if (hours.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Tooltip(
                    message:
                        'Perkiraan dari jam kantor 09.00–17.00 setempat. Bisa '
                        'bergeser satu jam saat musim panas, dan perusahaan '
                        'bisa meminta jam lain.',
                    child: _Fact(
                      Icons.access_time,
                      'Perkiraan jam kerja: ${hours.map((h) => '${h.region} ${h.wib}').join(', ')}',
                    ),
                  ),
                ],
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
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text('Lamar di $sourceName'),
                      onPressed: () => _apply(context),
                    ),
                    _TrackingButton(job: job, controller: controller),
                    _MoreMenu(job: job, controller: controller),
                  ],
                ),
                const SizedBox(height: 18),
                ReviewPanel(
                  services: services,
                  job: job,
                  descriptionText: plainText(descriptionHtml),
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
                      openInBrowser(context, url);
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

/// "Simpan" for an untracked job; once tracked, a menu to move it along.
class _TrackingButton extends StatelessWidget {
  const _TrackingButton({required this.job, required this.controller});

  final Job job;
  final JobsController controller;

  @override
  Widget build(BuildContext context) {
    final status = job.trackedStatus;
    if (status == null) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.star_border, size: 18),
        label: const Text('Simpan'),
        onPressed: () => controller.toggleSaved(job),
      );
    }
    return MenuAnchor(
      menuChildren: [
        for (final option in ApplicationStatus.values)
          MenuItemButton(
            leadingIcon: Icon(option == status ? Icons.check : null, size: 18),
            onPressed: () => controller.setStatus(job, option),
            child: Text(option.label),
          ),
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: const Icon(Icons.delete_outline, size: 18),
          onPressed: () => controller.untrack(job),
          child: const Text('Hapus dari pelacak'),
        ),
      ],
      builder: (context, menu, _) => FilledButton.tonalIcon(
        icon: const Icon(Icons.star, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Status: ${status.label}'),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.job, required this.controller});

  final Job job;
  final JobsController controller;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.visibility_off_outlined, size: 18),
          onPressed: () {
            controller.hide(job);
            showMessage(
              context,
              'Lowongan disembunyikan.',
              action: SnackBarAction(
                label: 'Urungkan',
                onPressed: () => controller.unhide(job),
              ),
            );
          },
          child: const Text('Sembunyikan lowongan ini'),
        ),
        if (job.company.isNotEmpty)
          MenuItemButton(
            leadingIcon: const Icon(Icons.block, size: 18),
            onPressed: () {
              controller.blockCompany(job.company);
              showMessage(
                context,
                'Lowongan dari ${job.company} tidak ditampilkan lagi.',
                action: SnackBarAction(
                  label: 'Urungkan',
                  onPressed: () => controller.unblockCompany(job.company),
                ),
              );
            },
            child: Text('Blokir ${job.company}'),
          ),
      ],
      builder: (context, menu, _) => IconButton(
        tooltip: 'Lainnya',
        icon: const Icon(Icons.more_vert),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

/// Lists the signs that this posting could be a fake offer.
class _WarningBanner extends StatelessWidget {
  const _WarningBanner(this.warnings);

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: scheme.onErrorContainer),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lowongan ini perlu dicek dengan teliti',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final warning in warnings) Text('• $warning'),
                  const SizedBox(height: 6),
                  const Text(
                    'Ciri-ciri ini sering ada di lowongan palsu, meski bisa '
                    'juga muncul di lowongan asli. Jangan pernah membayar '
                    'untuk melamar kerja, dan pastikan perusahaannya punya '
                    'situs resmi.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionLabel extends StatelessWidget {
  const _RegionLabel(this.fit);

  final RegionFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, text, color) = switch (fit) {
      RegionFit.open => (
        Icons.public,
        'Bisa dari Indonesia',
        const Color(0xFF2E7D32),
      ),
      RegionFit.restricted => (
        Icons.public_off,
        'Lokasi terbatas',
        scheme.error,
      ),
      RegionFit.unknown => (
        Icons.help_outline,
        'Lokasi tidak disebutkan',
        scheme.onSurfaceVariant,
      ),
    };
    return Tooltip(
      message:
          'Dinilai dari lokasi yang tertulis di lowongan. Periksa juga '
          'deskripsinya, karena syarat bisa berbeda.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: color),
          ),
        ],
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
