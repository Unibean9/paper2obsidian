import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/messages.dart';
import '../controllers/paper_controller.dart';
import '../models/paper_metadata.dart';
import '../models/project.dart';
import '../services/api_service.dart';
import '../services/bedrock_client.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart';
import '../services/paper_repository.dart';
import '../services/project_service.dart';
import '../services/vault_index_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/desktop_file_helper.dart';
import '../utils/vault_access.dart';
import '../widgets/chat/chat_tab.dart';
import '../widgets/project/main_home_view.dart';
import '../widgets/workspace/pdf_viewer_panel.dart';
import '../widgets/project/create_project_dialog.dart';
import '../widgets/settings/settings_dialog.dart';
import '../widgets/zotero/zotero_item_picker_dialog.dart';
import '../widgets/workspace/workspace_sidebar.dart';
import '../widgets/workspace/workspace_layout.dart';
import '../widgets/workspace/workspace_header.dart';
import '../widgets/workspace/library_tab.dart';
import '../widgets/common/panel_container.dart';
import '../widgets/common/animated_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const Duration _panelAnimationDuration = Duration(milliseconds: 220);

  // =========================================================================
  // BUCKET A — Workflow state
  // =========================================================================
  Project? _activeProject;
  bool _isSwitching = false;
  bool _isZoteroConfigured = false;
  bool _isFromZotero = false;
  String? _pendingZoteroItemKey; // key imported but not yet saved to Obsidian
  String? _currentPaperDedupKey; // dedupKey of paper currently open in viewer
  bool _isSidebarCollapsed = false;
  bool _isChatCollapsed = false;

  String get vaultPath => _activeProject?.vaultPath ?? '';
  String? get _activeCollectionKey => _activeProject?.zoteroCollectionKey;

  File? selectedPdf;

  PaperStatus _paperStatus = PaperStatus.idle;
  bool isLoading = false;
  String statusText = AppMessages.get(MessageKey.statusReady);
  String fullPdfText = '';
  List<String> paperCitations = [];
  List<String> progressLogs = [];
  static const String _globalChatKey = '__global__';
  final Map<String, List<Map<String, dynamic>>> _chatHistory = {};
  bool _indexStale = false;
  bool _bannerDismissed = false;
  int _indexRevision = 0;
  String _paperAbstract = '';
  int _workspaceSection = 0;
  bool _showHome = true;

  final _titleCtrl = TextEditingController();
  final _authorsCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _doiCtrl = TextEditingController();
  final _problemCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController();
  final _limitationCtrl = TextEditingController();
  final _datasetCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  late BedrockClient _bedrockClient;
  late ResearchApiService researchApiService;
  late VaultIndexService _vaultIndexService;
  late PaperController _paperController;
  final PaperRepository _paperRepository = PaperRepository(
    DatabaseService.instance,
  );

  // GlobalKey for triggering LibraryTab refresh after save
  final GlobalKey<LibraryTabState> _libraryTabKey =
      GlobalKey<LibraryTabState>();

  @override
  void initState() {
    super.initState();
    // Share one BedrockClient instance between the API service and the index service.
    _bedrockClient = BedrockClient(config: BedrockConfig.fromEnvironment());
    researchApiService = ResearchApiService(
      grobidUrl: 'http://localhost:8070',
      bedrockClient: _bedrockClient,
    );
    _vaultIndexService = VaultIndexService(bedrockClient: _bedrockClient);
    _paperController = PaperController(
      apiService: researchApiService,
      onLog: _addLog,
      vaultIndexService: _vaultIndexService,
      paperRepository: _paperRepository,
      onIndexingStatus: (msg) {
        if (!mounted) return;
        setState(() {
          statusText = msg ?? AppMessages.get(MessageKey.statusReady);
          // msg == null means background indexPaper completed — bump revision
          // so ChatTab.didUpdateWidget refreshes _availablePapers automatically.
          if (msg == null) _indexRevision++;
        });
      },
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorsCtrl.dispose();
    _venueCtrl.dispose();
    _yearCtrl.dispose();
    _doiCtrl.dispose();
    _problemCtrl.dispose();
    _keywordsCtrl.dispose();
    _limitationCtrl.dispose();
    _datasetCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  // =========================================================================
  // SETTINGS / LOGGING
  // =========================================================================

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      progressLogs.add(message);
      statusText = message; // Kept to drive log-box colour (green/red).
    });
  }

  Future<void> _loadSettings() async {
    await ProjectService.instance.init();

    // Migrate legacy vaultPath pref → default project if no projects exist yet.
    if (ProjectService.instance.projects.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final rawPath = prefs.getString('vaultPath') ?? '';
      final path = rawPath.isEmpty ? '' : p.normalize(rawPath);
      if (path.isNotEmpty) {
        final migrated = await ProjectService.instance.createProject(
          name: 'Default',
          vaultPath: path,
        );
        await ProjectService.instance.init();
        await DatabaseService.instance.openForVault(path);
        if (!mounted) return;
        setState(() => _activeProject = migrated);
        await _vaultIndexService.loadIndex(path);
        await _checkStaleness();
        await _loadChatHistory();
        return;
      }
    }

    final active = ProjectService.instance.activeProject;
    if (active != null && Directory(active.vaultPath).existsSync()) {
      await DatabaseService.instance.openForVault(active.vaultPath);
    }

    if (!mounted) return;
    setState(() => _activeProject = active);

    if (vaultPath.isNotEmpty) {
      await _vaultIndexService.loadIndex(vaultPath);
      await _checkStaleness();
      await _paperController.cleanupZoteroTempFiles(vaultPath);
    }
    await _loadChatHistory();
    await _refreshZoteroConfigured();
  }

  Future<void> _refreshZoteroConfigured() async {
    final configured = await _paperController.isZoteroConfigured;
    if (mounted) setState(() => _isZoteroConfigured = configured);
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('chat_history');
      if (stored == null) return;
      final raw = jsonDecode(stored) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _chatHistory.clear();
        raw.forEach((key, value) {
          _chatHistory[key] = (value as List)
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList();
        });
      });
    } catch (e) {
      AppLogger.log(
        'Failed to load chat history',
        category: LogCategory.other,
        error: e,
      );
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('chat_history', jsonEncode(_chatHistory));
    } catch (e) {
      AppLogger.log(
        'Failed to save chat history',
        category: LogCategory.other,
        error: e,
      );
    }
  }

  void _onChatMessagesChanged(List<Map<String, dynamic>> messages) {
    _chatHistory[_globalChatKey] = List.from(messages);
    _saveChatHistory(); // fire-and-forget
  }

  Future<void> _saveSettings() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppMessages.get(MessageKey.statusSettingsSaved))),
    );
  }

  /// Updates the active project's vault path (or creates a default project if
  /// none exists). Persists and opens the DB for the new path.
  Future<void> _applyVaultPath(String newPath) async {
    if (newPath.isEmpty) return;
    Project updated;
    final base = ProjectService.instance.activeProject ?? _activeProject;
    if (base != null) {
      updated = base.copyWith(vaultPath: newPath);
      await ProjectService.instance.updateProject(updated);
    } else {
      updated = await ProjectService.instance.createProject(
        name: 'Default',
        vaultPath: newPath,
      );
    }
    if (!mounted) return;
    setState(() => _activeProject = updated);
    await DatabaseService.instance.openForVault(newPath);
    await _vaultIndexService.loadIndex(newPath);
    await _checkStaleness();
  }

  void _showUserMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() => statusText = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
      ),
    );
  }

  // =========================================================================
  // VAULT READY CHECK
  // =========================================================================

  Future<bool> _ensureVaultReady() async {
    if (selectedPdf == null) {
      _showUserMessage(
        AppMessages.get(MessageKey.errorSelectPdfFirst),
        isError: true,
      );
      return false;
    }
    if (vaultPath.trim().isEmpty) {
      _showUserMessage(
        AppMessages.get(MessageKey.errorSetVaultPath),
        isError: true,
      );
      _showSettingsDialog(context);
      return false;
    }
    final bool vaultExists;
    try {
      vaultExists = await Directory(vaultPath).exists();
    } catch (e) {
      AppLogger.log(
        '_ensureVaultReady: directory check failed for "$vaultPath"',
        category: LogCategory.other,
        error: e,
      );
      _showUserMessage(
        AppMessages.get(MessageKey.errorVaultAccessFailed),
        isError: true,
      );
      return false;
    }
    if (!vaultExists) {
      _showUserMessage(
        AppMessages.get(MessageKey.errorVaultNotFound),
        isError: true,
      );
      return false;
    }

    if (await VaultAccess.canWriteToVault(vaultPath)) return true;

    if (VaultAccess.requiresPickerGrant) {
      _showUserMessage(
        AppMessages.get(MessageKey.errorMacosVaultBlocked),
        isError: true,
      );
      final picked = await VaultAccess.pickVaultWithWriteAccess(
        initialDirectory: vaultPath,
      );
      if (picked == null || picked.isEmpty) return false;
      final normalizedPick = p.normalize(picked);
      await _applyVaultPath(normalizedPick);
      if (await VaultAccess.canWriteToVault(vaultPath)) return true;
    }

    _showUserMessage(
      AppMessages.get(MessageKey.errorVaultWriteDenied),
      isError: true,
    );
    return false;
  }

  void _showSettingsDialog(BuildContext context) {
    showAnimatedDialog(
      context: context,
      child: SettingsDialog(
        initialVaultPath: vaultPath,
        onSave: (newPath) async {
          await _applyVaultPath(newPath);
          await _saveSettings();
        },
        onReindex: vaultPath.isEmpty
            ? null
            : () async {
                await _vaultIndexService.indexVault(vaultPath);
                if (mounted) setState(() => _indexStale = false);
                return _vaultIndexService.loadedPaperCount();
              },
        onZoteroApiKeyChanged: (_) => _refreshZoteroConfigured(),
        onProjectsChanged: () {
          if (mounted) {
            setState(() {
              _activeProject = ProjectService.instance.activeProject;
            });
          }
        },
      ),
    );
  }

  // =========================================================================
  // PDF PROCESSING
  // =========================================================================

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: defaultPdfPickerType,
        allowedExtensions: const ['pdf'],
        allowMultiple: false,
        withData: !kIsWeb,
        lockParentWindow: isDesktopPickerSupported,
        dialogTitle: 'Select a research paper (PDF)',
      );

      if (result == null || result.files.isEmpty) return; // User cancelled

      final picked = result.files.single;
      final file = await resolvePickedFile(picked);
      if (file == null) {
        _showUserMessage(
          AppMessages.get(MessageKey.errorPdfReadFailed),
          isError: true,
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        selectedPdf = file;
        _paperStatus = PaperStatus.uploaded;
        statusText = AppMessages.statusSelectedPdf(p.basename(file.path));
        fullPdfText = '';
        progressLogs.clear();
        // Clear form so the panel is visually blank until extraction runs.
        _titleCtrl.clear();
        _authorsCtrl.clear();
        _venueCtrl.clear();
        _yearCtrl.clear();
        _doiCtrl.clear();
        _keywordsCtrl.clear();
        _datasetCtrl.clear();
        _problemCtrl.clear();
        _limitationCtrl.clear();
        _summaryCtrl.clear();
        paperCitations = [];
        _paperAbstract = '';
      });
    } catch (e, stack) {
      AppLogger.log(
        'PDF picker error',
        category: LogCategory.ui,
        error: e,
        stackTrace: stack,
      );
      _showUserMessage(AppMessages.errorFilePickerFailed(e), isError: true);
    }
  }

  Future<void> _extractPaper() async {
    if (selectedPdf == null) return;
    setState(() => _paperStatus = PaperStatus.extracting);
    try {
      final PaperMetadata meta = await _paperController.processPdf(
        selectedPdf!,
      );
      // Guard against cancel — processPdf returns empty when isCancelled.
      if (mounted && !_paperController.isCancelled) {
        _applyMetadata(meta);
        if (mounted) setState(() => _paperStatus = PaperStatus.done);
      }
    } catch (e) {
      AppLogger.log(
        'PDF extraction failed',
        category: LogCategory.parse,
        error: e,
      );
      _addLog(AppMessages.errorPdfExtraction(e));
      if (mounted) setState(() => _paperStatus = PaperStatus.error);
    } finally {
      if (mounted && _paperController.isCancelled) {
        setState(
          () => _paperStatus = selectedPdf != null
              ? PaperStatus.uploaded
              : PaperStatus.idle,
        );
      }
    }
  }

  void _discardPaper() {
    setState(() {
      selectedPdf = null;
      _paperStatus = PaperStatus.idle;
      statusText = AppMessages.get(MessageKey.statusReady);
      progressLogs.clear();
      fullPdfText = '';
      _titleCtrl.clear();
      _authorsCtrl.clear();
      _venueCtrl.clear();
      _yearCtrl.clear();
      _doiCtrl.clear();
      _keywordsCtrl.clear();
      _datasetCtrl.clear();
      _problemCtrl.clear();
      _limitationCtrl.clear();
      _summaryCtrl.clear();
      paperCitations = [];
      _paperAbstract = '';
      _isFromZotero = false;
      _pendingZoteroItemKey = null;
    });
  }

  // =========================================================================
  // OBSIDIAN SAVE
  // =========================================================================

  Future<void> _saveToObsidian() async {
    if (!await _ensureVaultReady()) return;
    setState(() => isLoading = true);
    try {
      final meta = PaperMetadata(
        title: _titleCtrl.text,
        authors: _authorsCtrl.text,
        venue: _venueCtrl.text,
        year: _yearCtrl.text,
        doi: _doiCtrl.text,
        keywords: _keywordsCtrl.text,
        dataset: _datasetCtrl.text,
        problemStatement: _problemCtrl.text,
        limitation: _limitationCtrl.text,
        summary: _summaryCtrl.text,
        abstract: _paperAbstract,
        fullPdfText: fullPdfText,
        resolvedPdf: selectedPdf,
        zoteroItemKey: _pendingZoteroItemKey,
      );
      await _paperController.saveToObsidian(
        meta: meta,
        vaultPath: vaultPath,
        pdf: selectedPdf!,
      );
      if (!mounted) return;
      _showUserMessage(AppMessages.get(MessageKey.statusSavedToObsidian));
      setState(() => _pendingZoteroItemKey = null);
      // Refresh the library tab to show the newly saved note
      _libraryTabKey.currentState?.refresh();
    } on FileSystemException catch (e) {
      AppLogger.log(
        'FileSystemException saving to Obsidian',
        category: LogCategory.other,
        error: e,
      );
      _showUserMessage(AppMessages.errorSavePermission(e), isError: true);
    } catch (e) {
      AppLogger.log(
        'Unexpected error saving to Obsidian',
        category: LogCategory.other,
        error: e,
      );
      _showUserMessage(AppMessages.errorSaveFailed(e), isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // =========================================================================
  // LIBRARY
  // =========================================================================

  Future<void> _openPaperFromLibrary(String mdPath) async {
    final normalizedPath = p.isAbsolute(mdPath) ? p.normalize(mdPath) : mdPath;
    final displayName = p.isAbsolute(normalizedPath)
        ? p.basename(normalizedPath)
        : normalizedPath;

    setState(() {
      isLoading = true;
      progressLogs.clear();
      // Library papers are already processed; enable "Save to Obsidian".
      _paperStatus = PaperStatus.done;
    });
    _addLog(AppMessages.statusLoadingPaper(displayName));

    try {
      final PaperMetadata meta = await _paperController.openPaperFromLibrary(
        normalizedPath,
      );
      if (mounted) {
        _applyMetadata(meta);
      }
    } catch (e) {
      AppLogger.log(
        'Failed to open paper from library',
        category: LogCategory.other,
        error: e,
      );
      _addLog(AppMessages.errorLibraryItem(e));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<List<Map<String, String>>> _loadLibrary() {
    return _paperController.loadVaultLibrary(vaultPath);
  }

  // =========================================================================
  // VAULT INDEX
  // =========================================================================

  Future<void> _checkStaleness() async {
    if (vaultPath.isEmpty) return;
    try {
      final paperDir = Directory(p.join(vaultPath, 'Papers'));
      if (!await paperDir.exists()) return;
      final mdCount = paperDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .length;
      if (mdCount > _vaultIndexService.loadedPaperCount()) {
        if (mounted) setState(() => _indexStale = true);
      }
    } catch (e) {
      AppLogger.log(
        '_checkStaleness failed',
        category: LogCategory.other,
        error: e,
      );
    }
  }

  Future<void> _rebuildIndex() async {
    try {
      await _vaultIndexService.indexVault(vaultPath);
      if (mounted) {
        setState(() {
          _indexStale = false;
          _indexRevision++;
        });
      }
    } catch (e) {
      AppLogger.log(
        'Vault reindex failed',
        category: LogCategory.other,
        error: e,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vault re-index failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _handleCancel() {
    _paperController.cancel();
    setState(() => statusText = AppMessages.get(MessageKey.statusCancelled));
  }

  // =========================================================================
  // PROJECT SWITCHING
  // =========================================================================

  Future<void> _switchProject(Project project) async {
    if (_isSwitching || isLoading) return;
    setState(() => _isSwitching = true);
    try {
      await ProjectService.instance.switchProject(
        project,
        onVaultChanged: (newPath) async {
          await _vaultIndexService.loadIndex(newPath);
          await _checkStaleness();
        },
      );
      if (!mounted) return;
      setState(() {
        _activeProject = ProjectService.instance.activeProject;
        _libraryTabKey.currentState?.refresh();
        _indexRevision++;
      });
    } catch (e) {
      _showUserMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }

  void _showCreateProjectDialog() {
    showAnimatedDialog(
      context: context,
      child: CreateProjectDialog(
        onCreated: (project) async {
          await _openProject(project);
        },
      ),
    );
  }

  // =========================================================================
  // ZOTERO IMPORT / EXPORT
  // =========================================================================

  Future<void> _importFromZotero() async {
    final collectionKey = _activeCollectionKey;
    if (collectionKey == null || collectionKey.isEmpty) return;
    if (isLoading) return;

    setState(() => isLoading = true);
    try {
      final items = await _paperController.listZoteroItems(collectionKey);
      if (!mounted) return;

      final picked = await showAnimatedDialog<dynamic>(
        context: context,
        child:
            ZoteroItemPickerDialog(items: items, collectionName: collectionKey),
      );
      if (picked == null || !mounted) return;

      final meta = await _paperController.importFromZotero(
        vaultPath: vaultPath,
        item: picked,
        collectionKey: collectionKey,
      );
      if (mounted) {
        _applyMetadata(meta);
        setState(() => _paperStatus = PaperStatus.done);
      }
    } catch (e) {
      _addLog('❌ Zotero import failed: $e');
      if (mounted) setState(() => _paperStatus = PaperStatus.error);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Directly imports a Zotero item from the library tab (no picker dialog).
  Future<void> _importZoteroItem(dynamic item) async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final meta = await _paperController.importFromZotero(
        vaultPath: vaultPath,
        item: item,
        collectionKey: _activeCollectionKey ?? '',
      );
      if (mounted) {
        _applyMetadata(meta);
        setState(() {
          _paperStatus = PaperStatus.done;
          _pendingZoteroItemKey = meta.zoteroItemKey;
        });
      }
    } catch (e) {
      _addLog('❌ Zotero import failed: $e');
      if (mounted) setState(() => _paperStatus = PaperStatus.error);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _exportToZotero() async {
    final collectionKey = _activeCollectionKey;
    if (collectionKey == null || collectionKey.isEmpty) return;
    if (selectedPdf == null || isLoading) return;

    setState(() => isLoading = true);
    try {
      final meta = PaperMetadata(
        title: _titleCtrl.text,
        authors: _authorsCtrl.text,
        venue: _venueCtrl.text,
        year: _yearCtrl.text,
        doi: _doiCtrl.text,
        keywords: _keywordsCtrl.text,
        dataset: _datasetCtrl.text,
        problemStatement: _problemCtrl.text,
        limitation: _limitationCtrl.text,
        summary: _summaryCtrl.text,
        abstract: _paperAbstract,
        fullPdfText: fullPdfText,
        resolvedPdf: selectedPdf,
      );
      final zoteroKey = await _paperController.exportToZotero(
        collectionKey: collectionKey,
        meta: meta,
        pdf: selectedPdf!,
      );
      // Save the new Zotero key to the local DB record so the Zotero tab
      // shows "Saved" and prevents duplicate imports.
      if (_currentPaperDedupKey != null) {
        try {
          await _paperRepository.updateZoteroKey(
            _currentPaperDedupKey!,
            zoteroKey,
          );
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _isFromZotero = true);
        _libraryTabKey.currentState?.refresh();
        _showUserMessage('✅ Exported to Zotero successfully.');
      }
    } catch (e) {
      _addLog('❌ Zotero export failed: $e');
      _showUserMessage('Export to Zotero failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyMetadata(PaperMetadata meta) {
    setState(() {
      _titleCtrl.text = meta.title;
      _authorsCtrl.text = meta.authors;
      _venueCtrl.text = meta.venue;
      _yearCtrl.text = meta.year;
      _doiCtrl.text = meta.doi;
      _keywordsCtrl.text = meta.keywords;
      _datasetCtrl.text = meta.dataset;
      _problemCtrl.text = meta.problemStatement;
      _limitationCtrl.text = meta.limitation;
      _summaryCtrl.text = meta.summary;
      paperCitations = meta.citations;
      _paperAbstract = meta.abstract;
      _isFromZotero = meta.zoteroItemKey != null;
      _pendingZoteroItemKey = meta.zoteroItemKey;
      _currentPaperDedupKey = meta.dedupKey.isNotEmpty ? meta.dedupKey : null;
      if (meta.fullPdfText.isNotEmpty) fullPdfText = meta.fullPdfText;
      if (meta.resolvedPdf != null) selectedPdf = meta.resolvedPdf;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasProject = _activeProject != null && !_isSwitching;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: AppSpacing.sectionLarge + AppSpacing.xxl,
        titleSpacing: 14,
        actionsPadding: const EdgeInsets.only(right: 14),
        title: WorkspaceHeader(
          showHome: _showHome,
          activeProject: _activeProject,
          onBackHome: _openHome,
        ),
        centerTitle: false,
        actions: [
          WorkspaceHeaderActions(
            showHome: _showHome,
            hasProject: hasProject,
            isZoteroConfigured: _isZoteroConfigured,
            activeCollectionKey: _activeCollectionKey,
            isLoading: isLoading,
            onNewProject: _showCreateProjectDialog,
            onZotero: _importFromZotero,
            onSettings: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: _panelAnimationDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.02, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        child: _showHome || !hasProject
            ? KeyedSubtree(
                key: const ValueKey('home-body'),
                child: MainHomeView(
                  projects: ProjectService.instance.projects,
                  onCreateProject: _showCreateProjectDialog,
                  onOpenProject: _openProject,
                ),
              )
            : KeyedSubtree(
                key: const ValueKey('workspace-body'),
                child: _buildWorkspaceBody(),
              ),
      ),
    );
  }

  void _openHome() {
    if (!mounted) return;
    setState(() => _showHome = true);
  }

  Future<void> _openProject(Project project) async {
    await _switchProject(project);
    if (!mounted) return;
    setState(() => _showHome = false);
  }

  Widget _buildWorkspaceBody() {
    return WorkspaceLayout(
      isSidebarCollapsed: _isSidebarCollapsed,
      isChatCollapsed: _isChatCollapsed,
      onSidebarCollapseChanged: (collapsed) {
        setState(() => _isSidebarCollapsed = collapsed);
      },
      onChatCollapseChanged: (collapsed) {
        setState(() => _isChatCollapsed = collapsed);
      },
      workspaceSidebar: WorkspaceSidebar(
        selectedPdf: selectedPdf,
        vaultPath: vaultPath,
        isLoading: isLoading,
        paperStatus: _paperStatus,
        paperCitations: paperCitations,
        progressLogs: progressLogs,
        statusText: statusText,
        isZoteroConfigured: _isZoteroConfigured,
        isFromZotero: _isFromZotero,
        activeCollectionKey: _activeCollectionKey,
        pendingZoteroItemKey: _pendingZoteroItemKey,
        workspaceSection: _workspaceSection,
        titleCtrl: _titleCtrl,
        authorsCtrl: _authorsCtrl,
        venueCtrl: _venueCtrl,
        yearCtrl: _yearCtrl,
        doiCtrl: _doiCtrl,
        keywordsCtrl: _keywordsCtrl,
        datasetCtrl: _datasetCtrl,
        problemCtrl: _problemCtrl,
        limitationCtrl: _limitationCtrl,
        summaryCtrl: _summaryCtrl,
        libraryTabKey: _libraryTabKey,
        onDiscard: _discardPaper,
        onPickPdf: _pickPdf,
        onExtract: _extractPaper,
        onSave: _saveToObsidian,
        onImportZotero: _importFromZotero,
        onExportZotero: _exportToZotero,
        onOpenPaperFromLibrary: _openPaperFromLibrary,
        loadLibrary: _loadLibrary,
        loadZoteroCollection: _activeCollectionKey != null
            ? _paperController.loadZoteroCollectionWithStatus
            : null,
        onImportZoteroItem: _importZoteroItem,
        onSectionChanged: (index) {
          setState(() => _workspaceSection = index);
        },
        isCollapsed: _isSidebarCollapsed,
        onToggleCollapse: () => setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
        onSettings: () => _showSettingsDialog(context),
        onCancel: _handleCancel,
      ),
      pdfPanel: PdfViewerPanel(selectedPdf: selectedPdf),
      chatPanel: _buildChatPanel(),
    );
  }

  Widget _buildChatPanel() {
    return PanelContainer(
      padding: EdgeInsets.zero,
      child: ChatTab(
        vaultIndexService: _vaultIndexService,
        bedrockClient: _bedrockClient,
        showStaleBanner: _indexStale && !_bannerDismissed,
        onRebuildIndex: _rebuildIndex,
        onDismissBanner: () => setState(() => _bannerDismissed = true),
        initialMessages: List.from(_chatHistory[_globalChatKey] ?? []),
        onMessagesChanged: _onChatMessagesChanged,
        indexRevision: _indexRevision,
        isCollapsed: _isChatCollapsed,
        onToggleCollapse: () => setState(() => _isChatCollapsed = !_isChatCollapsed),
      ),
    );
  }
}
