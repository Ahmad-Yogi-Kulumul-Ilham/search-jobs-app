import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import '../../app_services.dart';
import '../../form_browser.dart';
import '../common.dart';
import '../cv/profile_dialog.dart';

/// Opens a job's application form in the app and helps fill it: the
/// applicant's details, the CV, and drafts for open questions. The user
/// reviews everything and submits the form themselves.
class ApplyPage extends StatefulWidget {
  const ApplyPage({super.key, required this.services, required this.job});

  final AppServices services;
  final Job job;

  @override
  State<ApplyPage> createState() => _ApplyPageState();
}

class _ApplyPageState extends State<ApplyPage> {
  late final FormBrowser _browser = widget.services.createBrowser();
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _ready = false;
  String? _browserError;
  bool _loading = false;
  String _url = '';
  int? _cvId;
  bool _filling = false;
  FillReport? _report;
  String? _fillError;

  AppServices get _services => widget.services;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await _browser.initialize();
    } on Object {
      if (mounted) {
        setState(
          () => _browserError =
              'Browser dalam aplikasi tidak bisa dibuka. Pastikan Microsoft '
              'Edge WebView2 Runtime terpasang, atau lamar lewat browser biasa.',
        );
      }
      return;
    }
    if (!mounted) return;
    _subscriptions
      ..add(_browser.url.listen((url) => setState(() => _url = url)))
      ..add(
        _browser.loading.listen(
          (loading) => setState(() => _loading = loading),
        ),
      );
    setState(() => _ready = true);
    await _browser.open(applicationUrl(widget.job));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _browser.dispose();
    super.dispose();
  }

  Cv? _selectedCv(List<Cv> cvs) =>
      cvs.where((cv) => cv.id == _cvId).firstOrNull ?? cvs.firstOrNull;

  Future<void> _fill() async {
    final cv = _selectedCv(_services.database.cvs.all());
    setState(() {
      _filling = true;
      _fillError = null;
    });
    try {
      final result = await _browser.run(
        fillFormScript(_services.applicantProfile, cv: cv),
      );
      final report = FillReport.parse(result);
      setState(() {
        _report = report;
        if (report == null) {
          _fillError = 'Halaman ini tidak bisa diisi otomatis.';
        }
      });
    } on Object {
      setState(() => _fillError = 'Halaman ini tidak bisa diisi otomatis.');
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  Future<bool> _answer(FormQuestion question, String text) async {
    final found = await _browser.run(
      answerQuestionScript(question.index, text),
    );
    return found == true || found == 'true';
  }

  void _markApplied() {
    final cv = _selectedCv(_services.database.cvs.all());
    final applications = _services.database.applications;
    final now = _services.now();
    final application = applications.track(
      widget.job,
      status: ApplicationStatus.applied,
      now: now,
    );
    if (cv != null) {
      final note = 'Dilamar ${shortDate(now)} dengan CV "${cv.name}".';
      applications.save(
        application.copyWith(
          notes: application.notes.isEmpty
              ? note
              : '${application.notes}\n$note',
          updatedAt: now,
        ),
      );
    }
    _services.dataChanged();
    showMessage(context, 'Ditandai sebagai Dilamar.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lamar: ${job.title}${job.company.isEmpty ? '' : ' · ${job.company}'}',
        ),
        actions: [
          IconButton(
            tooltip: 'Kembali di halaman',
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: _ready ? _browser.back : null,
          ),
          IconButton(
            tooltip: 'Muat ulang halaman',
            icon: const Icon(Icons.refresh),
            onPressed: _ready ? _browser.reload : null,
          ),
          IconButton(
            tooltip: 'Buka di browser biasa',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openInBrowser(
              context,
              _url.isEmpty ? applicationUrl(job) : _url,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Row(
        children: [
          Expanded(
            child: _browserError != null
                ? EmptyMessage(_browserError!)
                : _ready
                ? _browser.view()
                : const Center(child: CircularProgressIndicator()),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 380,
            child: ListenableBuilder(
              listenable: _services,
              builder: (context, _) => _buildPanel(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _services.applicantProfile;
    final cvs = _services.database.cvs.all();
    final cv = _selectedCv(cvs);
    final report = _report;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.job.warnings.isNotEmpty) ...[
          Text(
            'Lowongan ini punya tanda yang perlu dicek: '
            '${widget.job.warnings.join('; ')}. Jangan pernah membayar untuk '
            'melamar kerja.',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 12),
        ],
        Text('Bantuan mengisi', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text(
          'Aplikasi mengisi data diri dan melampirkan CV. Periksa semua isian, '
          'lalu tekan sendiri tombol kirim di formulir. Aplikasi tidak pernah '
          'mengirim lamaran atas nama Anda.',
        ),
        const SizedBox(height: 14),
        if (profile.isEmpty)
          OutlinedButton.icon(
            icon: const Icon(Icons.person_outline, size: 18),
            label: const Text('Isi data pelamar dulu'),
            onPressed: () => editApplicantProfile(context, _services),
          )
        else
          Row(
            children: [
              const Icon(Icons.person_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  [
                    profile.fullName,
                    profile.email,
                  ].where((part) => part.isNotEmpty).join(' · '),
                ),
              ),
              TextButton(
                onPressed: () => editApplicantProfile(context, _services),
                child: const Text('Ubah'),
              ),
            ],
          ),
        const SizedBox(height: 8),
        if (cvs.isEmpty)
          const Text(
            'Belum ada CV. Unggah di halaman CV agar bisa dilampirkan.',
          )
        else
          DropdownMenu<int>(
            label: const Text('CV yang dilampirkan'),
            initialSelection: cv!.id,
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: [
              for (final option in cvs)
                DropdownMenuEntry(value: option.id, label: option.name),
            ],
            onSelected: (id) => setState(() => _cvId = id),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: _filling
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_fix_high, size: 18),
          label: const Text('Isi otomatis'),
          onPressed: _ready && !_filling && !profile.isEmpty ? _fill : null,
        ),
        const SizedBox(height: 4),
        Text(
          'Tekan setelah formulir lamaran tampil di halaman. Kolom yang sudah '
          'terisi tidak diubah.',
          style: theme.textTheme.bodySmall,
        ),
        if (_fillError != null) ...[
          const SizedBox(height: 10),
          Text(_fillError!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        if (report != null) ..._buildReport(context, report, cv),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Sudah saya kirim, tandai Dilamar'),
          onPressed: _markApplied,
        ),
      ],
    );
  }

  List<Widget> _buildReport(BuildContext context, FillReport report, Cv? cv) {
    final theme = Theme.of(context);
    final filled = {for (final key in report.filled) _fieldLabels[key] ?? key};
    return [
      const SizedBox(height: 14),
      Text(
        filled.isEmpty
            ? 'Tidak ada kolom data diri yang dikenali di halaman ini.'
            : 'Terisi: ${filled.join(', ')}.',
      ),
      const SizedBox(height: 4),
      Text(
        report.resumeAttached
            ? 'CV terlampir.'
            : report.resumeFieldFound
            ? 'Kolom CV ditemukan tetapi belum terisi; lampirkan manual.'
            : 'Kolom unggah CV tidak ditemukan; lampirkan manual jika ada.',
        style: report.resumeAttached
            ? null
            : TextStyle(color: theme.colorScheme.error),
      ),
      if (report.questions.isNotEmpty) ...[
        const SectionTitle('Pertanyaan yang perlu dijawab'),
        for (final question in report.questions)
          _QuestionCard(
            key: ValueKey('${question.index}:${question.label}'),
            question: question,
            services: _services,
            job: widget.job,
            cv: cv,
            onInsert: (text) => _answer(question, text),
          ),
      ],
    ];
  }
}

const _fieldLabels = {
  'fullName': 'nama',
  'firstName': 'nama depan',
  'lastName': 'nama belakang',
  'email': 'email',
  'phone': 'telepon',
  'location': 'lokasi',
  'linkedin': 'LinkedIn',
  'github': 'GitHub',
  'portfolio': 'portofolio',
  'salaryExpectation': 'ekspektasi gaji',
  'noticePeriod': 'waktu mulai',
};

/// One open question on the form, with a saved answer or an AI draft.
class _QuestionCard extends StatefulWidget {
  const _QuestionCard({
    super.key,
    required this.question,
    required this.services,
    required this.job,
    required this.cv,
    required this.onInsert,
  });

  final FormQuestion question;
  final AppServices services;
  final Job job;
  final Cv? cv;
  final Future<bool> Function(String text) onInsert;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  late final _text = TextEditingController(
    text:
        bestSavedAnswer(
          widget.question.label,
          widget.services.database.cvs.answers(),
        )?.answer ??
        '',
  );
  late final bool _fromBank = _text.text.isNotEmpty;
  bool _drafting = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _draft() async {
    final reviewer = widget.services.reviewer();
    final cv = widget.cv;
    if (reviewer == null || cv == null) {
      setState(
        () =>
            _error = 'Butuh CV yang sudah diunggah dan API key di Pengaturan.',
      );
      return;
    }
    setState(() {
      _drafting = true;
      _error = null;
    });
    try {
      final (answer, usage) = await reviewer.draftAnswer(
        cv: cv,
        question: widget.question.label,
        job: widget.job,
        jobDescription: plainText(
          widget.services.database.jobs.descriptionOf(widget.job.id),
        ),
      );
      widget.services.recordSpend(usage);
      _text.text = answer;
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _drafting = false);
    }
  }

  Future<void> _insert() async {
    final found = await widget.onInsert(_text.text);
    if (!mounted) return;
    showMessage(
      context,
      found
          ? 'Jawaban diisikan ke formulir.'
          : 'Kolomnya tidak ditemukan lagi. Tekan "Isi otomatis" lalu coba '
                'lagi, atau salin manual.',
    );
  }

  void _saveToBank() {
    widget.services.database.cvs.saveAnswer(
      question: widget.question.label.replaceFirst(RegExp(r'\s*\*\s*$'), ''),
      answer: _text.text,
      now: widget.services.now(),
    );
    widget.services.dataChanged();
    showMessage(context, 'Disimpan ke bank jawaban.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = widget.question;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              question.required
                  ? '${question.label.replaceFirst(RegExp(r'\s*\*\s*$'), '')} (wajib)'
                  : question.label,
              style: theme.textTheme.titleSmall,
            ),
            if (_fromBank)
              Text(
                'Diambil dari bank jawaban',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              minLines: question.multiline ? 3 : 1,
              maxLines: question.multiline ? 8 : 2,
              decoration: const InputDecoration(
                hintText: 'Jawaban',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  icon: _drafting
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Draf AI'),
                  onPressed: _drafting ? null : _draft,
                ),
                ListenableBuilder(
                  listenable: _text,
                  builder: (context, _) {
                    final empty = _text.text.trim().isEmpty;
                    return Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: empty ? null : _insert,
                          child: const Text('Isi ke formulir'),
                        ),
                        IconButton(
                          tooltip: 'Salin',
                          icon: const Icon(Icons.copy, size: 16),
                          onPressed: empty
                              ? null
                              : () => Clipboard.setData(
                                  ClipboardData(text: _text.text),
                                ),
                        ),
                        IconButton(
                          tooltip: 'Simpan ke bank jawaban',
                          icon: const Icon(
                            Icons.bookmark_add_outlined,
                            size: 16,
                          ),
                          onPressed: empty ? null : _saveToBank,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
