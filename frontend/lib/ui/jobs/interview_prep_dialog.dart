import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import '../../app_services.dart';
import '../common.dart';

/// Question sets still being made, by job id and CV id.
final _running = <(String, int), Future<StoredInterviewPrep>>{};

/// Interview practice for one job with one CV: likely questions with
/// sample answers, and feedback on answers the user writes. The questions
/// are kept, so opening it again costs nothing.
class InterviewPrepDialog extends StatefulWidget {
  const InterviewPrepDialog({
    super.key,
    required this.services,
    required this.job,
    required this.cv,
    required this.descriptionText,
  });

  final AppServices services;
  final Job job;
  final Cv cv;
  final String descriptionText;

  @override
  State<InterviewPrepDialog> createState() => _InterviewPrepDialogState();
}

class _InterviewPrepDialogState extends State<InterviewPrepDialog> {
  StoredInterviewPrep? _stored;
  bool _loading = false;
  String? _error;

  AppServices get _services => widget.services;

  @override
  void initState() {
    super.initState();
    _stored = _services.database.cvs.interviewPrepFor(
      widget.job.id,
      widget.cv.id,
    );
    if (_stored == null) _prepare();
  }

  Future<void> _prepare() async {
    final reviewer = _services.reviewer();
    if (reviewer == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final key = (widget.job.id, widget.cv.id);
    try {
      // Closing the dialog does not stop a request; a reopened dialog
      // waits for it rather than paying for a second one.
      // The block body matters: returning the removed future from
      // whenComplete would make this future wait on itself.
      final stored = await (_running[key] ??= _generate(reviewer)
          .whenComplete(() {
            _running.remove(key);
          }));
      if (mounted) setState(() => _stored = stored);
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Asks for questions and keeps them; runs to the end even if the dialog
  /// closes meanwhile, since the request is paid for either way.
  Future<StoredInterviewPrep> _generate(CvReviewer reviewer) async {
    final services = _services;
    final job = widget.job;
    final cv = widget.cv;
    final (prep, usage) = await reviewer.interviewPrep(
      cv: cv,
      job: job,
      jobDescription: widget.descriptionText,
    );
    final stored = StoredInterviewPrep(
      jobId: job.id,
      cvId: cv.id,
      prep: prep,
      model: usage.model,
      costUsd: usage.costUsd,
      createdAt: services.now(),
    );
    services.database.cvs.saveInterviewPrep(stored);
    services.recordSpend(usage);
    return stored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final stored = _stored;
    final provider = _services.aiModel.provider.shortName;

    Widget body;
    if (stored == null) {
      body = Center(
        child: _loading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    '$provider sedang menyiapkan pertanyaan dari CV dan '
                    'lowongan ini. Biasanya butuh satu sampai dua menit.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error ?? 'Atur AI di Pengaturan dulu.',
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _prepare,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
      );
    } else {
      final prep = stored.prep;
      body = ListView(
        children: [
          Text(prep.overview),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          for (final kind in QuestionKind.values)
            if (prep.questions.where((q) => q.kind == kind).toList()
                case final questions when questions.isNotEmpty) ...[
              SectionTitle(kind.label),
              for (final question in questions)
                _QuestionCard(
                  // A fresh card per question resets practice after a redo.
                  key: ValueKey('${stored.createdAt}${question.question}'),
                  question: question,
                  services: _services,
                  job: widget.job,
                  cv: widget.cv,
                  descriptionText: widget.descriptionText,
                ),
            ],
          if (prep.questionsToAsk.isNotEmpty) ...[
            const SectionTitle('Pertanyaan untuk ditanyakan balik'),
            for (final question in prep.questionsToAsk)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText('• $question'),
              ),
          ],
          if (prep.toPrepare.isNotEmpty) ...[
            const SectionTitle('Yang perlu disiapkan'),
            for (final item in prep.toPrepare)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $item'),
              ),
          ],
          const SizedBox(height: 12),
          Text(
            'Dibuat ${timeAgo(stored.createdAt)} oleh ${stored.model} · '
            'biaya ${_services.formatUsd(stored.costUsd)}. Contoh jawaban '
            'hanya memakai isi CV; lengkapi bagian dalam [kurung siku] '
            'dengan pengalaman Anda sendiri.',
            style: muted,
          ),
        ],
      );
    }

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Latihan interview'),
          Text(
            '${widget.job.title} · ${widget.job.company} · CV: '
            '${widget.cv.name}',
            style: muted,
          ),
        ],
      ),
      content: SizedBox(width: 820, height: 620, child: body),
      actions: [
        if (stored != null)
          TextButton.icon(
            icon: _loading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(_loading ? 'Menyiapkan…' : 'Buat ulang'),
            onPressed: _loading ? null : _prepare,
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

/// One question: why it is asked, how to answer, a sample answer, and a
/// place to practise with feedback.
class _QuestionCard extends StatefulWidget {
  const _QuestionCard({
    super.key,
    required this.question,
    required this.services,
    required this.job,
    required this.cv,
    required this.descriptionText,
  });

  final InterviewQuestion question;
  final AppServices services;
  final Job job;
  final Cv cv;
  final String descriptionText;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard>
    with AutomaticKeepAliveClientMixin<_QuestionCard> {
  final _answer = TextEditingController();
  AnswerFeedback? _feedback;
  String? _cost;
  String? _error;
  bool _rating = false;

  /// The list builds cards lazily; keep one alive once it holds a practice
  /// answer or paid feedback, so scrolling away does not lose them.
  @override
  bool get wantKeepAlive =>
      _answer.text.isNotEmpty || _feedback != null || _rating;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _rate() async {
    final answer = _answer.text.trim();
    final reviewer = widget.services.reviewer();
    if (answer.isEmpty || reviewer == null) return;
    setState(() {
      _rating = true;
      _error = null;
      updateKeepAlive();
    });
    try {
      final (feedback, usage) = await reviewer.answerFeedback(
        cv: widget.cv,
        job: widget.job,
        jobDescription: widget.descriptionText,
        question: widget.question.question,
        answer: answer,
      );
      widget.services.recordSpend(usage);
      if (mounted) {
        setState(() {
          _feedback = feedback;
          _cost = widget.services.formatUsd(usage.costUsd);
          updateKeepAlive();
        });
      }
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _rating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final question = widget.question;
    final feedback = _feedback;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(text, style: theme.textTheme.labelLarge),
    );

    Widget copyable(String text, String what) => Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: SelectableText(text)),
          IconButton(
            tooltip: 'Salin $what',
            icon: const Icon(Icons.copy, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              showMessage(context, 'Disalin.');
            },
          ),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(question.question),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label('Kenapa ditanyakan'),
          Text(question.why),
          label('Tips menjawab'),
          Text(question.tips),
          label('Contoh jawaban dari CV Anda'),
          copyable(question.sampleAnswer, 'contoh jawaban'),
          const Divider(height: 28),
          label('Latihan: tulis jawaban Anda sendiri'),
          TextField(
            controller: _answer,
            minLines: 3,
            maxLines: 10,
            onChanged: (_) => setState(updateKeepAlive),
            decoration: const InputDecoration(
              hintText: 'Tulis seperti Anda akan mengucapkannya…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.tonalIcon(
                icon: _rating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.grading, size: 18),
                label: Text(_rating ? 'Menilai…' : 'Nilai jawaban'),
                onPressed: _rating || _answer.text.trim().isEmpty
                    ? null
                    : _rate,
              ),
              if (_cost != null) ...[
                const SizedBox(width: 10),
                Text('Biaya $_cost', style: theme.textTheme.bodySmall),
              ],
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          if (feedback != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= feedback.rating ? Icons.star : Icons.star_border,
                    size: 20,
                    color: Colors.amber.shade700,
                  ),
                const SizedBox(width: 8),
                Text('${feedback.rating}/5'),
              ],
            ),
            const SizedBox(height: 6),
            Text(feedback.summary),
            if (feedback.strengths.isNotEmpty) ...[
              label('Sudah bagus'),
              for (final item in feedback.strengths) Text('• $item'),
            ],
            if (feedback.improvements.isNotEmpty) ...[
              label('Bisa diperbaiki'),
              for (final item in feedback.improvements) Text('• $item'),
            ],
            label('Versi yang lebih kuat'),
            copyable(feedback.improvedAnswer, 'versi yang lebih kuat'),
          ],
        ],
      ),
    );
  }
}
