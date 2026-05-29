import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

Future<File?> resolvePickedFile(PlatformFile picked) async {
  final path = picked.path;
  if (path != null && path.isNotEmpty) {
    final file = File(path);
    if (await file.exists()) return file;
  }

  final bytes = picked.bytes;
  if (bytes != null && bytes.isNotEmpty) {
    final name = picked.name.isNotEmpty ? picked.name : 'document.pdf';
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final tempDir = Directory.systemTemp.createTempSync('paper_to_obsidian_');
    final tempFile = File('${tempDir.path}/$safeName');
    await tempFile.writeAsBytes(bytes, flush: true);
    return tempFile;
  }

  return null;
}

bool get isDesktopPickerSupported {
  if (kIsWeb) return false;
  return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}

FileType get defaultPdfPickerType => FileType.custom;
