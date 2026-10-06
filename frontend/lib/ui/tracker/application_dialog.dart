import 'package:flutter/material.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import '../../app_services.dart';
import '../common.dart';

/// Edits one tracked application: status, interview time, and notes.
class ApplicationDialog extends StatefulWidget {
  const ApplicationDialog({
    super.key,
    required this.application,
    required this.services,
  });

  final Application application;
  final AppServices services;

  @override
  State<ApplicationDialog> createState() => _ApplicationDialogState();
}

class _ApplicationDialogState extends State<ApplicationDialog> {
  late ApplicationStatus _status = widget.application.status;
  late DateTime? _interviewAt = widget.application.interviewAt;
  late final _notes = TextEditingController(text: widget.application.notes);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickInterview() async {
    final now = DateTime.now();
    final start = _interviewAt ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (time == null) return;
    setState(() {
      _interviewAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _save() {
    final store = widget.services.database.applications;
    final now = DateTime.now();
    // Changing the status goes through setStatus so the applied date is set.
    final current = _status == widget.application.status
        ? widget.application
        : store.setStatus(widget.application.jobId, _status, now: now)!;
    store.save(
      current.copyWith(
        notes: _notes.text.trim(),
        interviewAt: () => _interviewAt,
        updatedAt: now,
      ),
    );
    widget.services.dataChanged();
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final sure = await confirm(
      context,
      title: 'Hapus dari pelacak?',
      message: 'Status dan catatan untuk lamaran ini akan hilang.',
      confirmLabel: 'Hapus',
    );
    if (!sure || !mounted) return;
    widget.services.database.applications.delete(widget.application.jobId);
    widget.services.dataChanged();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final application = widget.application;
    final theme = Theme.of(context);
    final interviewAt = _interviewAt;
    return AlertDialog(
      title: Text(application.title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  if (application.company.isNotEmpty) application.company,
                  widget.services.registry.nameOf(application.sourceId),
                ].join(' · '),
                style: theme.textTheme.bodyMedium,
              ),
              if (application.url.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Buka halaman lowongan'),
                    onPressed: () => openInBrowser(context, application.url),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownMenu<ApplicationStatus>(
                label: const Text('Status'),
                initialSelection: _status,
                width: 460,
                dropdownMenuEntries: [
                  for (final status in ApplicationStatus.values)
                    DropdownMenuEntry(value: status, label: status.label),
                ],
                onSelected: (status) =>
                    setState(() => _status = status ?? _status),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      interviewAt == null
                          ? 'Jadwal interview: belum diatur'
                          : 'Jadwal interview: ${shortDateTime(interviewAt)}',
                    ),
                  ),
                  if (interviewAt != null)
                    IconButton(
                      tooltip: 'Hapus jadwal',
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _interviewAt = null),
                    ),
                  TextButton(
                    onPressed: _pickInterview,
                    child: Text(interviewAt == null ? 'Atur' : 'Ubah'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  hintText:
                      'Kontak HR, versi CV yang dikirim, hasil interview…',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
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

/// What the user typed for a job found outside the app's sources.
typedef ManualApplicationDraft = ({
  String title,
  String company,
  String url,
  ApplicationStatus status,
});

/// Collects a job found elsewhere, such as on LinkedIn, to track it by hand.
class ManualApplicationDialog extends StatefulWidget {
  const ManualApplicationDialog({super.key});

  @override
  State<ManualApplicationDialog> createState() =>
      _ManualApplicationDialogState();
}

class _ManualApplicationDialogState extends State<ManualApplicationDialog> {
  final _title = TextEditingController();
  final _company = TextEditingController();
  final _url = TextEditingController();
  ApplicationStatus _status = ApplicationStatus.applied;
  bool _showError = false;

  @override
  void dispose() {
    _title.dispose();
    _company.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    if (_title.text.trim().isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop<ManualApplicationDraft>(context, (
      title: _title.text,
      company: _company.text,
      url: _url.text,
      status: _status,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah lamaran manual'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Untuk lowongan dari situs lain, misalnya LinkedIn atau '
                'kenalan.',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Posisi',
                border: const OutlineInputBorder(),
                errorText: _showError ? 'Posisi wajib diisi' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _company,
              decoration: const InputDecoration(
                labelText: 'Perusahaan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Tautan lowongan (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownMenu<ApplicationStatus>(
              label: const Text('Status'),
              initialSelection: _status,
              width: 460,
              dropdownMenuEntries: [
                for (final status in ApplicationStatus.values)
                  DropdownMenuEntry(value: status, label: status.label),
              ],
              onSelected: (status) => _status = status ?? _status,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Tambah')),
      ],
    );
  }
}
