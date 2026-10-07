import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import '../../app_services.dart';
import '../common.dart';
import 'profile_dialog.dart';

/// The user's CV versions and their bank of saved answers.
class CvPage extends StatelessWidget {
  const CvPage({super.key, required this.services});

  final AppServices services;

  Future<void> _upload(BuildContext context) async {
    final file = await services.chooseCvFile();
    if (file == null || !context.mounted) return;
    final dot = file.name.lastIndexOf('.');
    try {
      services.database.cvs.add(
        name: dot > 0 ? file.name.substring(0, dot) : file.name,
        fileName: file.name,
        bytes: file.bytes,
        now: services.now(),
      );
    } on FormatException catch (error) {
      showMessage(context, error.message);
      return;
    }
    services.dataChanged();
  }

  Future<void> _rename(BuildContext context, Cv cv) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) =>
          _TextDialog(title: 'Ganti nama CV', label: 'Nama', initial: cv.name),
    );
    if (name == null || name.trim().isEmpty) return;
    services.database.cvs.rename(cv.id, name);
    services.dataChanged();
  }

  Future<void> _delete(BuildContext context, Cv cv) async {
    final sure = await confirm(
      context,
      title: 'Hapus ${cv.name}?',
      message: 'Hasil review untuk CV ini ikut terhapus.',
      confirmLabel: 'Hapus',
    );
    if (!sure) return;
    services.database.cvs.delete(cv.id);
    services.dataChanged();
  }

  Future<void> _editAnswer(BuildContext context, [SavedAnswer? answer]) =>
      showDialog<void>(
        context: context,
        builder: (context) =>
            _AnswerDialog(services: services, existing: answer),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services,
      builder: (context, _) {
        final cvs = services.database.cvs.all();
        final answers = services.database.cvs.answers();
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'CV dan jawaban',
              actions: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('Unggah CV'),
                  onPressed: () => _upload(context),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  const SectionTitle('Data pelamar'),
                  _ProfileSummary(services: services),
                  const SectionTitle('Versi CV'),
                  if (cvs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Belum ada CV. Unggah CV dalam bentuk PDF atau Word '
                        '(DOCX). Anda bisa menyimpan beberapa versi, misalnya '
                        'satu untuk tiap jenis posisi.',
                      ),
                    ),
                  for (final cv in cvs)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        cv.format == CvFormat.pdf
                            ? Icons.picture_as_pdf_outlined
                            : Icons.description_outlined,
                      ),
                      title: Text(cv.name),
                      subtitle: Text(
                        '${cv.fileName} · diunggah ${timeAgo(cv.createdAt)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Ganti nama',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _rename(context, cv),
                          ),
                          IconButton(
                            tooltip: 'Hapus CV',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(context, cv),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'CV tersimpan di komputer ini. Saat Anda meminta review '
                      'atau draf, CV dikirim ke '
                      '${services.aiModel.provider.label} untuk diproses.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Row(
                    children: [
                      const Expanded(child: SectionTitle('Bank jawaban')),
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Tambah jawaban'),
                          onPressed: () => _editAnswer(context),
                        ),
                      ),
                    ],
                  ),
                  if (answers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Simpan jawaban untuk pertanyaan yang sering muncul di '
                        'formulir lamaran, misalnya "Ceritakan tentang diri '
                        'Anda" atau ekspektasi gaji, supaya tinggal disalin.',
                      ),
                    ),
                  for (final answer in answers)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(answer.question),
                      subtitle: Text(
                        answer.answer,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _editAnswer(context, answer),
                      trailing: IconButton(
                        tooltip: 'Salin jawaban',
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: answer.answer));
                          showMessage(context, 'Jawaban disalin.');
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final profile = services.applicantProfile;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_outline),
      title: Text(profile.isEmpty ? 'Belum diisi' : profile.fullName),
      subtitle: Text(
        profile.isEmpty
            ? 'Nama, email, telepon, dan LinkedIn untuk mengisi formulir '
                  'lamaran otomatis.'
            : [
                profile.email,
                profile.phone,
                profile.location,
              ].where((part) => part.isNotEmpty).join(' · '),
      ),
      trailing: TextButton(
        onPressed: () => editApplicantProfile(context, services),
        child: Text(profile.isEmpty ? 'Isi' : 'Ubah'),
      ),
    );
  }
}

/// Adds or edits a saved answer, with an AI draft on request.
class _AnswerDialog extends StatefulWidget {
  const _AnswerDialog({required this.services, this.existing});

  final AppServices services;
  final SavedAnswer? existing;

  @override
  State<_AnswerDialog> createState() => _AnswerDialogState();
}

class _AnswerDialogState extends State<_AnswerDialog> {
  late final _question = TextEditingController(text: widget.existing?.question);
  late final _answer = TextEditingController(text: widget.existing?.answer);
  bool _drafting = false;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _draft() async {
    final services = widget.services;
    final reviewer = services.reviewer();
    final cvs = services.database.cvs.all();
    if (_question.text.trim().isEmpty) {
      setState(() => _error = 'Tulis pertanyaannya dulu.');
      return;
    }
    if (reviewer == null || cvs.isEmpty) {
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
        cv: cvs.first,
        question: _question.text.trim(),
      );
      services.recordSpend(usage);
      _answer.text = answer;
    } on AiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _drafting = false);
    }
  }

  void _save() {
    if (_question.text.trim().isEmpty || _answer.text.trim().isEmpty) {
      setState(() => _error = 'Pertanyaan dan jawaban wajib diisi.');
      return;
    }
    widget.services.database.cvs.saveAnswer(
      id: widget.existing?.id,
      question: _question.text,
      answer: _answer.text,
      now: widget.services.now(),
    );
    widget.services.dataChanged();
    Navigator.pop(context);
  }

  void _delete() {
    widget.services.database.cvs.deleteAnswer(widget.existing!.id);
    widget.services.dataChanged();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Tambah jawaban' : 'Ubah jawaban'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _question,
              autofocus: widget.existing == null,
              decoration: const InputDecoration(
                labelText: 'Pertanyaan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answer,
              minLines: 5,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Jawaban',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Buat draf dengan AI'),
                  onPressed: _drafting ? null : _draft,
                ),
                if (_drafting)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(onPressed: _delete, child: const Text('Hapus')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.initial,
  });

  final String title;
  final String label;
  final String initial;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _text,
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
