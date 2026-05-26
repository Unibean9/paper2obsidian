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
    if (kIsWeb) return false;
    if (vaultPath.trim().isEmpty || vaultPath.trim() == '.') return false;
    try {
      // Normalize path for cross-platform compatibility (fixes Windows namespace issues)
      final normalizedPath = p.normalize(vaultPath);

      // Reject relative paths and current directory
      if (normalizedPath.isEmpty || normalizedPath == '.') return false;

      // Ensure vault root directory exists first
      final vaultDir = Directory(normalizedPath);
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }

      final foldersToTest = [
        'Papers',
        'Authors',
        'Tags',
        'Datasets',
        'Years',
        'Venues',
      ];

      for (final folderName in foldersToTest) {
        final folder = Directory(p.join(normalizedPath, folderName));
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }

        // Probe test on Papers and Tags folders to catch permission issues
        // on both primary docs and metadata folders (covers existing read-only edge case)
        if (folderName == 'Papers' || folderName == 'Tags') {
          final probe = File(p.join(folder.path, '_write_probe_'));
          await probe.writeAsString('ok', flush: true);
          await probe.delete();
        }
      }
      return true;
    } catch (e) {
      debugPrint('VaultAccess: canWriteToVault failed for "$vaultPath": $e');
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
