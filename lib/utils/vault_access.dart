import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// macOS sandbox: only paths from [FilePicker] can be written reliably.
class VaultAccess {
  VaultAccess._();

  static bool get requiresPickerGrant =>
      !kIsWeb && (Platform.isMacOS || Platform.isIOS);

  static Future<bool> canWriteToVault(String vaultPath) async {
    if (vaultPath.trim().isEmpty) return false;
    try {
      final papers = Directory(p.join(vaultPath, 'Papers'));
      if (!await papers.exists()) {
        await papers.create(recursive: true);
      }
      final probe = File(p.join(papers.path, '.write_probe'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Re-pick vault folder when sandbox blocks writes (macOS).
  static Future<String?> pickVaultWithWriteAccess({
    String? initialDirectory,
  }) async {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Obsidian vault (grant write access)',
      lockParentWindow: true,
      initialDirectory: initialDirectory,
    );
  }
}
