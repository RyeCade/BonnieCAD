import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class PickedPlan {
  PickedPlan({required this.name, required this.text});

  final String name;
  final String text;
}

/// Result of a save attempt. [saved] is false when the user cancels.
class SaveResult {
  const SaveResult({required this.saved, this.pathOrName});

  final bool saved;
  final String? pathOrName;
}

/// Browser-friendly open/save via the system/file picker (downloads on web).
class PlanFiles {
  static Future<PickedPlan?> open() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['boncad', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError(
        'Could not read file bytes. Try again or pick a different file.',
      );
    }
    return PickedPlan(
      name: file.name,
      text: utf8.decode(bytes),
    );
  }

  static Future<SaveResult> saveText(String fileName, String text) async {
    final safeName = fileName.endsWith('.boncad') || fileName.endsWith('.json')
        ? fileName
        : '$fileName.boncad';
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save BonnieCAD plan',
      fileName: safeName,
      type: FileType.custom,
      allowedExtensions: const ['boncad', 'json'],
      bytes: Uint8List.fromList(utf8.encode(text)),
    );
    // Desktop returns a path on success and null on cancel.
    // Web starts a download and may return null even when save succeeded.
    if (kIsWeb) {
      return SaveResult(saved: true, pathOrName: path ?? safeName);
    }
    if (path == null) {
      return const SaveResult(saved: false);
    }
    return SaveResult(saved: true, pathOrName: path);
  }
}
