import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import '../../app_services.dart';
import '../common.dart';

/// Reviews the user's CV against one job with AI, and drafts a cover
/// letter for it.
class ReviewPanel extends StatefulWidget {
  const ReviewPanel({
    super.key,
    required this.services,
    required this.job,
    required this.descriptionText,
  });

  final AppServices services;
  final Job job;
  final String descriptionText;

  @override
  State<ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends State<ReviewPanel> {
  int? _cvId;
  bool _busy = false;
  String? _error;

  AppServices get _services => widget.services;

  Cv? _selectedCv(List<Cv> cvs) {
    if (cvs.isEmpty) return null;
    return cvs.where((cv) => cv.id == _cvId).firstOrNull ?? cvs.first;
  }

  Future<void> _review(Cv cv) async {
    final reviewer = _services.reviewer();
    if (reviewer == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (review, usage) = await reviewer.review(
        cv: cv,
        job: widget.job,
        jobDescription: widget.descriptionText,
      );
      _services.database.cvs.saveReview(
        StoredReview(
          jobId: widget.job.id,
          cvId: cv.id,
          review: review,
          model: usage.model,
          costUsd: usage.costUsd,
          createdAt: _services.now(),
        ),
      );
      _services.recordSpend(usage);
      _services.dataChanged();
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _coverLetter(Cv cv) async {
    final reviewer = _services.reviewer();
    if (reviewer == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final CoverLetter letter;
    final AiUsage usage;
    try {
      (letter, usage) = await reviewer.coverLetter(
        cv: cv,
        job: widget.job,
        jobDescription: widget.descriptionText,
      );
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _services.recordSpend(usage);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _CoverLetterDialog(
        letter: letter,
        cost: _services.formatUsd(usage.costUsd),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cvs = _services.database.cvs.all();
    final cv = _selectedCv(cvs);
    final hasKey = _services.aiReady;
    final provider = _services.aiModel.provider;
    final stored = cv == null
        ? null
        : _services.database.cvs
              .reviewsFor(widget.job.id)
              .where((review) => review.cvId == cv.id)
              .firstOrNull;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 20),
                const SizedBox(width: 8),
                Text('Kecocokan CV', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            if (cvs.isEmpty)
              const Text(
                'Unggah CV Anda di halaman CV untuk menilai kecocokannya '
                'dengan lowongan ini.',
              )
            else if (!hasKey)
              Text(
                provider == AiProvider.openrouter && _services.apiKey != null
                    ? 'Isi ID model OpenRouter di Pengaturan untuk memakai '
                          'review dengan AI.'
                    : 'Masukkan API key ${provider.shortName} di Pengaturan '
                          'untuk memakai review dengan AI.',
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (cvs.length > 1)
                    DropdownMenu<int>(
                      initialSelection: cv!.id,
                      label: const Text('CV'),
                      width: 240,
                      dropdownMenuEntries: [
                        for (final option in cvs)
                          DropdownMenuEntry(
                            value: option.id,
                            label: option.name,
                          ),
                      ],
                      onSelected: (id) => setState(() => _cvId = id),
                    ),
                  FilledButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(
                      stored == null ? 'Review dengan AI' : 'Review ulang',
                    ),
                    onPressed: _busy ? null : () => _review(cv!),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Buat cover letter'),
                    onPressed: _busy ? null : () => _coverLetter(cv!),
                  ),
                  if (_busy)
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            if (_busy) ...[
              const SizedBox(height: 8),
              Text(
                '${provider.shortName} sedang membaca CV dan lowongan. '
                'Biasanya butuh setengah sampai dua menit.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (stored != null) ...[
              const SizedBox(height: 14),
              _ReviewResult(stored: stored, services: _services),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewResult extends StatelessWidget {
  const _ReviewResult({required this.stored, required this.services});

  final StoredReview stored;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final review = stored.review;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScoreBadge(review.score, large: true),
            const SizedBox(width: 14),
            Expanded(child: Text(review.verdict)),
          ],
        ),
        if (review.locationCheck.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.public, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(review.locationCheck)),
            ],
          ),
        ],
        _Bullets('Yang sudah cocok', review.strengths),
        _Bullets('Yang belum terlihat di CV', review.gaps),
        if (review.missingKeywords.isNotEmpty) ...[
          const SectionTitle('Kata kunci yang bisa ditambahkan'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final keyword in review.missingKeywords)
                Chip(
                  label: Text(keyword),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tambahkan hanya yang memang Anda kuasai.',
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (review.suggestions.isNotEmpty) ...[
          const SectionTitle('Saran perbaikan CV'),
          for (final suggestion in review.suggestions)
            _SuggestionTile(suggestion),
        ],
        const SizedBox(height: 10),
        Text(
          'Direview ${timeAgo(stored.createdAt)} oleh ${stored.model} · '
          'biaya ${services.formatUsd(stored.costUsd)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.title, this.items);

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $item'),
          ),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile(this.suggestion);

  final CvSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  suggestion.section,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: 'Salin teks baru',
                icon: const Icon(Icons.copy, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: suggestion.revised));
                  showMessage(context, 'Teks disalin.');
                },
              ),
            ],
          ),
          if (suggestion.original.isNotEmpty) ...[
            Text(
              suggestion.original,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(suggestion.revised),
          const SizedBox(height: 6),
          Text(
            suggestion.reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverLetterDialog extends StatelessWidget {
  const _CoverLetterDialog({required this.letter, required this.cost});

  final CoverLetter letter;
  final String cost;

  @override
  Widget build(BuildContext context) {
    final text = '${letter.subject}\n\n${letter.body}';
    return AlertDialog(
      title: const Text('Draf cover letter'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subjek: ${letter.subject}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                Text(letter.body),
                const SizedBox(height: 12),
                Text(
                  'Periksa dan sesuaikan sebelum dikirim, terutama bagian '
                  'dalam [kurung siku]. Biaya: $cost.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            showMessage(context, 'Cover letter disalin.');
          },
          child: const Text('Salin'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

/// A match score as a coloured pill, such as `82%`.
class ScoreBadge extends StatelessWidget {
  const ScoreBadge(this.score, {super.key, this.large = false});

  final int score;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (score) {
      >= 80 => (const Color(0xFF2E7D32), Colors.white),
      >= 60 => (scheme.primary, scheme.onPrimary),
      >= 40 => (const Color(0xFFB26A00), Colors.white),
      _ => (scheme.error, scheme.onError),
    };
    final style = large
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.labelSmall;
    return Tooltip(
      message: 'Skor kecocokan CV dari review AI',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 12 : 7,
          vertical: large ? 6 : 2,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(large ? 10 : 8),
        ),
        child: Text('$score%', style: style?.copyWith(color: foreground)),
      ),
    );
  }
}
