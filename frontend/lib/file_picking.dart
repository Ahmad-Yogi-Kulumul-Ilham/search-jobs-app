import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// A file the user picked: its name and contents.
typedef PickedFile = ({String name, Uint8List bytes});

/// Opens the system file dialog for a CV. Returns null when cancelled.
Future<PickedFile?> pickCvFile() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'CV (PDF atau Word)', extensions: ['pdf', 'docx']),
    ],
  );
  if (file == null) return null;
  return (name: file.name, bytes: await file.readAsBytes());
}
