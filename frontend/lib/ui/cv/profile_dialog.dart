import 'package:flutter/material.dart';
import 'package:search_jobs_backend/search_jobs_backend.dart';

import '../../app_services.dart';

/// Opens the form for the details application forms ask for.
Future<void> editApplicantProfile(
  BuildContext context,
  AppServices services,
) async {
  final profile = await showDialog<ApplicantProfile>(
    context: context,
    builder: (context) => _ProfileDialog(initial: services.applicantProfile),
  );
  if (profile != null) services.applicantProfile = profile;
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.initial});

  final ApplicantProfile initial;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final Map<String, TextEditingController> _fields = {
    for (final entry in widget.initial.toJson().entries)
      entry.key: TextEditingController(text: '${entry.value}'),
  };
  bool _showError = false;

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final email = _fields['email']!.text.trim();
    if (_fields['fullName']!.text.trim().isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(
      context,
      ApplicantProfile.fromJson({
        for (final entry in _fields.entries) entry.key: entry.value.text,
      }),
    );
  }

  Widget _field(String key, String label, {String? hint, String? error}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _fields[key],
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            errorText: error,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Data pelamar'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  'Dipakai untuk mengisi formulir lamaran secara otomatis. '
                  'Tulis seperti yang ingin Anda tampilkan ke perusahaan luar '
                  'negeri.',
                ),
              ),
              _field(
                'fullName',
                'Nama lengkap',
                error: _showError && _fields['fullName']!.text.trim().isEmpty
                    ? 'Wajib diisi'
                    : null,
              ),
              _field(
                'email',
                'Email',
                error: _showError ? 'Isi email yang valid' : null,
              ),
              _field('phone', 'Telepon', hint: '+62 812 3456 7890'),
              _field('location', 'Lokasi', hint: 'Jakarta, Indonesia'),
              _field('linkedin', 'LinkedIn', hint: 'https://linkedin.com/in/…'),
              _field('github', 'GitHub (opsional)'),
              _field('portfolio', 'Portofolio atau situs (opsional)'),
              _field(
                'salaryExpectation',
                'Ekspektasi gaji (opsional)',
                hint: 'USD 3,000 per month',
              ),
              _field(
                'noticePeriod',
                'Bisa mulai kerja (opsional)',
                hint: '2 weeks notice',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}
