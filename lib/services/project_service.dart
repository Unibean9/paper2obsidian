import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../exceptions/user_facing_exception.dart';
import '../models/project.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart';

class ProjectService {
  ProjectService._();
  static final ProjectService instance = ProjectService._();

  static const String _activeProjectIdKey = 'activeProjectId';

  List<Project> _projects = [];
  Project? _activeProject;

  List<Project> get projects => List.unmodifiable(_projects);
  Project? get activeProject => _activeProject;

  Future<File> _projectsFile() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'projects.json'));
  }

  Future<void> init() async {
    await _load();
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_activeProjectIdKey);
    if (savedId != null) {
      _activeProject = _projects.where((pr) => pr.id == savedId).firstOrNull;
    }
    _activeProject ??= _projects.isNotEmpty ? _projects.first : null;
  }

  Future<void> _load() async {
    final file = await _projectsFile();
    if (!await file.exists()) {
      _projects = [];
      return;
    }
    try {
      final content = await file.readAsString();
      final list = jsonDecode(content) as List;
      _projects = list
          .map((e) => Project.fromJson(e as Map<String, dynamic>))
          .toList();
    } on FormatException catch (e) {
      AppLogger.log(
        'projects.json parse error — starting with empty list',
        category: LogCategory.other,
        error: e,
      );
      _projects = [];
    } on FileSystemException catch (e) {
      AppLogger.log(
        'projects.json read error — starting with empty list',
        category: LogCategory.other,
        error: e,
      );
      _projects = [];
    }
  }

  Future<void> _save() async {
    final file = await _projectsFile();
    final tmp = File('${file.path}.tmp');
    final content = jsonEncode(_projects.map((p) => p.toJson()).toList());
    await tmp.writeAsString(content, flush: true);
    try {
      await tmp.rename(file.path);
    } on FileSystemException catch (e) {
      AppLogger.log(
        'Atomic rename failed, falling back to direct write',
        category: LogCategory.other,
        error: e,
      );
      await file.writeAsString(content, flush: true);
    }
  }

  Future<Project> createProject({
    required String name,
    required String vaultPath,
    String? locale,
    String? zoteroCollectionKey,
  }) async {
    final project = Project(
      name: name,
      vaultPath: vaultPath,
      locale: locale,
      zoteroCollectionKey: zoteroCollectionKey,
    );
    _projects.add(project);
    await _save();
    return project;
  }

  Future<void> updateProject(Project updated) async {
    final idx = _projects.indexWhere((p) => p.id == updated.id);
    if (idx < 0) return;
    _projects[idx] = updated;
    if (_activeProject?.id == updated.id) _activeProject = updated;
    await _save();
  }

  Future<void> deleteProject(String id) async {
    _projects.removeWhere((p) => p.id == id);
    await _save();
  }

  /// Switches the active project. Validates that the vault path exists before
  /// opening the database. Throws [UserFacingException] if the path is missing.
  Future<void> switchProject(
    Project project, {
    required Future<void> Function(String vaultPath) onVaultChanged,
  }) async {
    if (!Directory(project.vaultPath).existsSync()) {
      throw UserFacingException(
        userMessage:
            'Vault folder not found: "${project.vaultPath}". '
            'The folder may have been moved or deleted.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProjectIdKey, project.id);

    final touched = project.copyWith(lastOpenedAt: DateTime.now());
    final idx = _projects.indexWhere((p) => p.id == project.id);
    if (idx >= 0) _projects[idx] = touched;
    _activeProject = touched;
    await _save();

    await DatabaseService.instance.openForVault(project.vaultPath);
    await onVaultChanged(project.vaultPath);
  }
}
