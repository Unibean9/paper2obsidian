import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Loads `AWS_*` / `BEDROCK_*` variables from a local `.env` file (gitignored).
class EnvConfig {
  EnvConfig._();

  static final Map<String, String> _values = {};
  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  /// Call once at startup before using [get].
  static Future<void> load() async {
    if (_loaded) return;
    _values.clear();

    final file = await _findEnvFile();
    if (file != null) {
      final content = await file.readAsString();
      _parse(content);
      if (kDebugMode) {
        debugPrint('Loaded .env from ${file.path} (${_values.length} keys)');
      }
    } else if (kDebugMode) {
      debugPrint(
        'No .env file found. Copy .env.example to .env or use app Settings.',
      );
    }

    _loaded = true;
  }

  static String? get(String key) {
    final v = _values[key];
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static Future<File?> _findEnvFile() async {
    final candidates = <String>{};

    try {
      candidates.add(p.join(Directory.current.path, '.env'));
    } catch (_) {}

    if (!kIsWeb) {
      try {
        var dir = Directory.current;
        for (var i = 0; i < 6; i++) {
          candidates.add(p.join(dir.path, '.env'));
          final parent = dir.parent;
          if (parent.path == dir.path) break;
          dir = parent;
        }
      } catch (_) {}
    }

    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) return file;
    }
    return null;
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
