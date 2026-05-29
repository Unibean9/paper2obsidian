import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;

class EnvConfig {
  EnvConfig._();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    wOptions: WindowsOptions(),
  );
  static const _zoteroApiKeyStorageKey = 'zotero_api_key';
  static const _zoteroUserIdPrefKey = 'resolvedZoteroUserId';

  static const String assetPath = '.env';

  static final Map<String, String> _values = {};
  static bool _loaded = false;
  static String? _loadedFrom;

  static bool get isLoaded => _loaded;
  static String? get loadedFrom => _loadedFrom;
  static bool get hasAwsCredentials =>
      (_values['AWS_ACCESS_KEY_ID'] ?? '').isNotEmpty &&
      (_values['AWS_SECRET_ACCESS_KEY'] ?? '').isNotEmpty;

  static Future<void> load() async {
    if (_loaded) return;
    _values.clear();
    _loadedFrom = null;

    try {
      final content = await rootBundle.loadString(assetPath);
      _parse(content);
      _loadedFrom = 'asset:$assetPath';
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Env: bundled $assetPath not found ($e). Trying project file…',
        );
      }
    }

    if (!hasAwsCredentials && !kIsWeb) {
      final projectFile = await _findProjectEnvFile();
      if (projectFile != null) {
        try {
          _parse(await projectFile.readAsString());
          _loadedFrom = projectFile.path;
        } on IOException catch (e) {
          if (kDebugMode) {
            debugPrint('Env: could not read ${projectFile.path}: $e');
          }
        }
      }
    }

    if (kDebugMode) {
      if (hasAwsCredentials) {
        debugPrint(
          'Env: loaded ${_values.length} keys from $_loadedFrom '
          '(text: ${_values['BEDROCK_TEXT_MODEL_ID'] ?? "default"}, '
          'embed: ${_values['BEDROCK_EMBED_MODEL_ID'] ?? "default"})',
        );
      } else {
        debugPrint(
          'Env: missing AWS keys. Copy .env.example → .env before flutter run/build.',
        );
      }
    }

    _loaded = true;
  }

  static String? get(String key) {
    final v = _values[key];
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static Future<File?> _findProjectEnvFile() async {
    for (final dirPath in _projectRootCandidates()) {
      final envFile = File(p.join(dirPath, '.env'));
      if (!await envFile.exists()) continue;
      try {
        await envFile.readAsBytes();
        return envFile;
      } on IOException {
        continue;
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

    try {
      addDir(Directory.current);
    } catch (_) {}
    try {
      addDir(File(Platform.resolvedExecutable).parent);
    } catch (_) {}

    return roots;
  }

  static void _parse(String content) {
    for (final rawLine in content.split('\n')) {
      var line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('export ')) line = line.substring(7).trim();

      final eq = line.indexOf('=');
      if (eq <= 0) continue;

      final key = line.substring(0, eq).trim();
      var value = line.substring(eq + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      }
      _values[key] = value.trim();
    }
  }

  // =========================================================================
  // ZOTERO CREDENTIALS — stored in Windows Credential Manager via DPAPI
  // =========================================================================

  static Future<String> getZoteroApiKey() async {
    return await _secureStorage.read(key: _zoteroApiKeyStorageKey) ?? '';
  }

  static Future<void> setZoteroApiKey(String key) async {
    if (key.isEmpty) {
      await _secureStorage.delete(key: _zoteroApiKeyStorageKey);
    } else {
      await _secureStorage.write(key: _zoteroApiKeyStorageKey, value: key);
    }
  }

  static Future<String?> getResolvedZoteroUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_zoteroUserIdPrefKey);
  }

  static Future<void> setResolvedZoteroUserId(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId == null) {
      await prefs.remove(_zoteroUserIdPrefKey);
    } else {
      await prefs.setString(_zoteroUserIdPrefKey, userId);
    }
  }
}
