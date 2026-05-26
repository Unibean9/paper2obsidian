import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Loads `AWS_*` / `BEDROCK_*` variables from project `.env` (gitignored).
class EnvConfig {
  EnvConfig._();

  static final Map<String, String> _values = {};
  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  /// Call once at startup before using [get]. Never throws — app can run without `.env`.
  static Future<void> load() async {
    if (_loaded) return;
    _values.clear();

    final file = await _findEnvFile();
    if (file != null) {
      try {
        final content = await file.readAsString();
        _parse(content);
        if (kDebugMode) {
          debugPrint('Loaded .env from ${file.path} (${_values.length} keys)');
        }
      } on IOException catch (e) {
        if (kDebugMode) {
          debugPrint(
            'Could not read .env at ${file.path} ($e). '
            'Use Settings or run from project root with a local .env next to pubspec.yaml.',
          );
        }
      }
    } else if (kDebugMode) {
      debugPrint(
        'No project .env found. Copy .env.example to .env in the repo root, or use Settings.',
      );
    }

    _loaded = true;
  }

  static String? get(String key) {
    final v = _values[key];
    if (v == null || v.isEmpty) return null;
    return v;
  }

  /// Only `.env` next to [pubspec.yaml] — avoids picking `~/.env` on macOS sandbox.
  static Future<File?> _findEnvFile() async {
    final orderedDirs = _projectRootCandidates();

    for (final dirPath in orderedDirs) {
      final envFile = File(p.join(dirPath, '.env'));
      if (!await envFile.exists()) continue;

      try {
        // Verify sandbox allows read before returning.
        await envFile.readAsBytes();
        return envFile;
      } on IOException {
        if (kDebugMode) {
          debugPrint('Skipping unreadable .env: ${envFile.path}');
        }
      }
    }
    return null;
  }

  static List<String> _projectRootCandidates() {
    final seen = <String>{};
    final roots = <String>[];

    void addDir(Directory? start) {
      if (start == null) return;
      var dir = start;
      for (var i = 0; i < 12; i++) {
        final path = p.normalize(dir.path);
        if (path.isEmpty || seen.contains(path)) break;
        seen.add(path);

        if (File(p.join(path, 'pubspec.yaml')).existsSync()) {
          roots.add(path);
        }

        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }

    if (!kIsWeb) {
      try {
        addDir(Directory.current);
      } catch (_) {}

      try {
        addDir(File(Platform.resolvedExecutable).parent);
      } catch (_) {}

      // `flutter run` often sets this to the project directory.
      final flutterAssets = Platform.environment['FLUTTER_ASSETS_DIR'];
      if (flutterAssets != null && flutterAssets.isNotEmpty) {
        try {
          addDir(Directory(flutterAssets));
        } catch (_) {}
      }
    }

    return roots;
  }

  static void _parse(String content) {
    for (final rawLine in content.split('\n')) {
      var line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('export ')) {
        line = line.substring(7).trim();
      }

      final eq = line.indexOf('=');
      if (eq <= 0) continue;

      final key = line.substring(0, eq).trim();
      var value = line.substring(eq + 1).trim();

      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }

      _values[key] = value;
    }
  }
}
