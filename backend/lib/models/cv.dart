import 'dart:typed_data';

/// File formats a CV can be uploaded in.
enum CvFormat {
  pdf('application/pdf'),
  docx(
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ),
  text('text/plain');

  const CvFormat(this.mimeType);

  final String mimeType;

  /// Reads the format from a file name, or null when it is not supported.
  static CvFormat? fromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return pdf;
    if (lower.endsWith('.docx')) return docx;
    if (lower.endsWith('.txt') || lower.endsWith('.md')) return text;
    return null;
  }
}

/// One version of the user's CV.
class Cv {
  const Cv({
    required this.id,
    required this.name,
    required this.fileName,
    required this.format,
    required this.bytes,
    required this.text,
    required this.createdAt,
  });

  final int id;

  /// The user's label for this version, such as "CV Frontend".
  final String name;
  final String fileName;
  final CvFormat format;
  final Uint8List bytes;

  /// Text extracted locally, for formats that have it (DOCX and plain text).
  /// Empty for PDF, which the AI model reads directly.
  final String text;
  final DateTime createdAt;
}

/// A saved answer to a question that application forms keep asking.
class SavedAnswer {
  const SavedAnswer({
    required this.id,
    required this.question,
    required this.answer,
    required this.updatedAt,
  });

  final int id;
  final String question;
  final String answer;
  final DateTime updatedAt;
}
