import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Extracts the plain text of a Word document: one line per paragraph, with
/// table cells separated by tabs. Throws [FormatException] when [bytes] is
/// not a DOCX file.
String docxText(List<int> bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const FormatException('Bukan file DOCX yang valid');
  }
  final entry = archive.findFile('word/document.xml');
  if (entry == null) {
    throw const FormatException('Bukan file DOCX yang valid');
  }
  final XmlDocument document;
  try {
    document = XmlDocument.parse(
      utf8.decode(entry.content, allowMalformed: true),
    );
  } on XmlException {
    throw const FormatException('Isi DOCX tidak bisa dibaca');
  }

  final lines = <String>[];
  for (final paragraph in document.findAllElements('w:p')) {
    final buffer = StringBuffer();
    for (final node in paragraph.descendants.whereType<XmlElement>()) {
      switch (node.name.qualified) {
        case 'w:t':
          buffer.write(node.innerText);
        case 'w:tab':
          buffer.write('\t');
        case 'w:br' || 'w:cr':
          buffer.write('\n');
      }
    }
    lines.add(buffer.toString());
  }
  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
