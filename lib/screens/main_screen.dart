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
import '../services/api_service.dart';
import '../services/bedrock_client.dart';
import '../services/logger_service.dart';
import '../services/vault_index_service.dart';
import '../utils/desktop_file_helper.dart';
import '../utils/vault_access.dart';
import '../widgets/actions_panel.dart';
import '../widgets/chat_tab.dart';
import '../widgets/citations_tab.dart';
import '../widgets/library_tab.dart';
import '../widgets/metadata_tab.dart';
import '../widgets/panel_container.dart';
import '../widgets/pdf_viewer_panel.dart';
import '../widgets/settings_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // =========================================================================
  // BUCKET A — Workflow state
  // =========================================================================
  String vaultPath = '';
  File? selectedPdf;

  /// Extraction state machine. Drives [ActionsPanel] button rendering.
  /// [PaperStatus.extracting] = pipeline running; [isLoading] = save running.
  PaperStatus _paperStatus = PaperStatus.idle;

  /// True only during the Save-to-Obsidian async operation (not during extraction).
  bool isLoading = false;

  // NOTE: _isCancelled is NOT in Bucket A — it lives in PaperController.isCancelled (single source of truth)
  String statusText = AppMessages.get(MessageKey.statusReady);
  String fullPdfText = '';
  List<String> paperCitations = [];
  List<String> progressLogs = [];

  // ── Chat history persistence (Phase 2) ──────────────────────────────────
  /// Normalized path of the currently active library paper, used as the
  /// key in [_chatHistory]. Null when no library paper is open.
  String? _currentPaperPath;

  /// Sentinel key used in [_chatHistory] when no library paper is open.
  /// Must not be a valid OS path (no separator, no drive letter).
  static const String _globalChatKey = '__global__';

  /// Per-paper chat message threads keyed by normalized md-file path,
  /// or [_globalChatKey] for the vault-wide chat when no paper is open.
  /// Value type is `Map<String, dynamic>` (not String) so Phase 3 can
  /// store a `sources` key alongside `role` and `content`.
  final Map<String, List<Map<String, dynamic>>> _chatHistory = {};

  // Vault index state (Phase 6)
  bool _indexStale = false;
  bool _bannerDismissed = false;

  // Holds the last extracted abstract so it survives through to saveToObsidian.
  // Not shown in the form (read-only pipeline output).
  String _paperAbstract = '';

  // =========================================================================
  // BUCKET B — Form controllers (created and disposed by this screen)
  // =========================================================================
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

  // =========================================================================
  // SERVICES AND CONTROLLER
  // =========================================================================
  late BedrockClient _bedrockClient;
  late ResearchApiService researchApiService;
  late VaultIndexService _vaultIndexService;
  late PaperController _paperController;

  // GlobalKey for triggering LibraryTab refresh after save
  final GlobalKey<LibraryTabState> _libraryTabKey = GlobalKey<LibraryTabState>();

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
      onIndexingStatus: (msg) {
        if (!mounted) return;
        setState(() => statusText = msg ?? AppMessages.get(MessageKey.statusReady));
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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Normalize vault path for cross-platform compatibility (but keep empty as empty)
      final rawPath = prefs.getString('vaultPath') ?? '';
      vaultPath = rawPath.isEmpty ? '' : p.normalize(rawPath);
    });
    // LibraryTab reloads automatically via didUpdateWidget when vaultPath changes
    if (vaultPath.isNotEmpty) {
      await _vaultIndexService.loadIndex(vaultPath);
      await _checkStaleness();
    }
    await _loadChatHistory();
  }

  // ─── Chat history persistence ───────────────────────────────────────────────

  /// Loads the persisted per-paper chat history from [SharedPreferences].
  /// Called once at startup via [_loadSettings].
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

  /// Serialises [_chatHistory] to JSON and writes it to [SharedPreferences].
  /// Fire-and-forget — never throws.
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

  /// Callback wired into [ChatTab.onMessagesChanged].
  ///
  /// Keeps [_chatHistory] in sync with every message add inside the tab,
  /// then persists asynchronously. Always copies the list to avoid aliasing.
  void _onChatMessagesChanged(List<Map<String, dynamic>> messages) {
    final key = _currentPaperPath ?? _globalChatKey;
    _chatHistory[key] = List.from(messages);
    _saveChatHistory(); // fire-and-forget
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vaultPath', vaultPath);
    if (!mounted) return; // ← guard before ScaffoldMessenger to prevent use-after-dispose crash
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppMessages.get(MessageKey.statusSettingsSaved))),
    );
  }

  void _showUserMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() => statusText = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
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
      setState(() => vaultPath = p.normalize(picked));
      await _saveSettings();
      if (await VaultAccess.canWriteToVault(vaultPath)) return true;
    }

    _showUserMessage(
      AppMessages.get(MessageKey.errorVaultWriteDenied),
      isError: true,
    );
    return false;
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => SettingsDialog(
        initialVaultPath: vaultPath,
        onSave: (newPath) async {
          setState(() => vaultPath = newPath);
          await _saveSettings();
          // Reload index for the new vault path
          if (newPath.isNotEmpty) {
            await _vaultIndexService.loadIndex(newPath);
            await _checkStaleness();
          }
        },
        onReindex: vaultPath.isEmpty
            ? null
            : () async {
                await _vaultIndexService.indexVault(vaultPath);
                if (mounted) setState(() => _indexStale = false);
                return _vaultIndexService.loadedPaperCount();
              },
      ),
    );
  }

  // =========================================================================
  // PDF PROCESSING
  // =========================================================================

  /// Step 1 of 2: open file picker and stage the chosen PDF.
  ///
  /// Sets [_paperStatus] to [PaperStatus.uploaded] and shows the PDF in the
  /// viewer. Does NOT start extraction — the user must tap "Extract Paper".
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

  /// Step 2 of 2: run the extraction pipeline on the staged PDF.
  ///
  /// Called when the user taps "Extract Paper". Transitions:
  ///   uploaded → extracting → done (or error on failure).
  ///
  /// **Single owner rule**: the `finally` block is the sole writer of
  /// [_paperStatus] on the cancel path; [_handleCancel] must NOT touch it.
  Future<void> _extractPaper() async {
    if (selectedPdf == null) return;
    setState(() => _paperStatus = PaperStatus.extracting);
    try {
      final PaperMetadata meta = await _paperController.processPdf(selectedPdf!);
      // Guard against cancel — processPdf returns empty when isCancelled.
      if (mounted && !_paperController.isCancelled) {
        _applyMetadata(meta);
        if (mounted) setState(() => _paperStatus = PaperStatus.done);
      }
    } catch (e) {
      AppLogger.log('PDF extraction failed', category: LogCategory.parse, error: e);
      _addLog(AppMessages.errorPdfExtraction(e));
      if (mounted) setState(() => _paperStatus = PaperStatus.error);
    } finally {
      // Single owner rule: on cancel the try/catch leave _paperStatus == extracting;
      // restore to uploaded (retry) or idle (if discarded mid-flight).
      if (mounted && _paperController.isCancelled) {
        setState(
          () => _paperStatus =
              selectedPdf != null ? PaperStatus.uploaded : PaperStatus.idle,
        );
      }
    }
  }

  /// Discards the currently staged PDF and resets all state to [PaperStatus.idle].
  ///
  /// Only callable from [PaperStatus.uploaded] or [PaperStatus.error] — the UI
  /// does not expose "Discard" during extraction.
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
      );
      await _paperController.saveToObsidian(
        meta: meta,
        vaultPath: vaultPath,
        pdf: selectedPdf!,
      );
      if (!mounted) return;
      _showUserMessage(AppMessages.get(MessageKey.statusSavedToObsidian));
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
    final normalizedPath = p.normalize(mdPath);

    // ── Snapshot ordering rule (Phase 2) ──────────────────────────────────
    // _chatHistory[_currentPaperPath] is kept in sync by _onChatMessagesChanged,
    // so it already holds the latest messages. Updating _currentPaperPath in the
    // same setState below triggers ChatTab to rebuild with ValueKey(normalizedPath),
    // seeding from _chatHistory[normalizedPath]. The snapshot is already in the map.

    setState(() {
      isLoading = true;
      progressLogs.clear();
      // Key change happens here — ChatTab rebuilds with new ValueKey after setState.
      _currentPaperPath = normalizedPath;
      // Library papers are already processed; enable "Save to Obsidian".
      _paperStatus = PaperStatus.done;
    });
    _addLog(AppMessages.statusLoadingPaper(p.basename(mdPath)));

    try {
      final PaperMetadata meta =
          await _paperController.openPaperFromLibrary(mdPath);
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

  /// Checks whether the persisted paper count is less than the current
  /// number of `.md` files in `Papers/`. Sets `_indexStale` if outdated.
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
      AppLogger.log('_checkStaleness failed', category: LogCategory.other, error: e);
    }
  }

  /// Triggered by the staleness banner "Rebuild" button.
  Future<void> _rebuildIndex() async {
    try {
      await _vaultIndexService.indexVault(vaultPath);
      if (mounted) setState(() => _indexStale = false);
    } catch (e) {
      AppLogger.log('Vault reindex failed', category: LogCategory.other, error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vault re-index failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // =========================================================================
  // CANCEL
  // =========================================================================

  /// Cancel handler: signals the controller to stop.
  ///
  /// Does NOT touch [_paperStatus] — the `finally` block in [_extractPaper]
  /// is the single owner of cancel-path status transitions (single-owner rule).
  void _handleCancel() {
    _paperController.cancel();
    setState(() => statusText = AppMessages.get(MessageKey.statusCancelled));
  }

  // =========================================================================
  // APPLY METADATA
  // =========================================================================

  /// Applies a returned PaperMetadata to all form controllers and Bucket A variables.
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
      // Abstract is pipeline-only (not editable); preserve for saveToObsidian.
      _paperAbstract = meta.abstract;
      // Apply Bucket A fields from metadata result
      if (meta.fullPdfText.isNotEmpty) fullPdfText = meta.fullPdfText;
      if (meta.resolvedPdf != null) selectedPdf = meta.resolvedPdf;
    });
  }

  // =========================================================================
  // BUILD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Paper to Obsidian',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton.tonalIcon(
              onPressed: () => _showSettingsDialog(context),
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Settings'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------
            // COLUMN 1: ACTIONS PANEL
            // ------------------------------------------
            SizedBox(
              width: 260,
              child: ActionsPanel(
                paperStatus: _paperStatus,
                isLoading: isLoading,
                vaultPath: vaultPath,
                selectedPdf: selectedPdf,
                progressLogs: progressLogs,
                statusText: statusText,
                primaryColor: primaryColor,
                onPickPdf: _pickPdf,
                onExtract: _extractPaper,
                onDiscard: _discardPaper,
                onSaveToObsidian: _saveToObsidian,
                onCancel: _handleCancel,
              ),
            ),

            const SizedBox(width: 20),

            // ------------------------------------------
            // COLUMN 2: PDF PREVIEW WITH ZOOM & TEXT INTERACTION TOOLBAR
            // ------------------------------------------
            Expanded(
              flex: 5,
              child: PdfViewerPanel(
                selectedPdf: selectedPdf,
                primaryColor: primaryColor,
              ),
            ),

            const SizedBox(width: 20),

            // ------------------------------------------
            // COLUMN 3: 4-TAB MANAGEMENT PANEL (METADATA, CHAT, CITATIONS, LIBRARY)
            // ------------------------------------------
            Expanded(
              flex: 4,
              child: PanelContainer(
                padding: EdgeInsets.zero,
                child: DefaultTabController(
                  length: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: Colors.grey.shade50,
                        child: TabBar(
                          indicatorColor: primaryColor,
                          indicatorWeight: 3,
                          labelColor: primaryColor,
                          unselectedLabelColor: Colors.grey.shade600,
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.auto_awesome, size: 18),
                              text: 'Metadata',
                            ),
                            Tab(
                              icon: Icon(Icons.chat_bubble_outline, size: 18),
                              text: 'AI Chat',
                            ),
                            Tab(
                              icon: Icon(Icons.format_quote, size: 18),
                              text: 'Citations',
                            ),
                            Tab(
                              icon: Icon(Icons.local_library, size: 18),
                              text: 'Library',
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // TAB 1: METADATA FORM
                            MetadataTab(
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
                            ),

                            // TAB 2: VAULT RAG CHAT
                            // ValueKey(_currentPaperPath) ensures Flutter
                            // invalidates State on every paper switch, so
                            // initState re-seeds from initialMessages.
                            ChatTab(
                              key: ValueKey(_currentPaperPath),
                              vaultIndexService: _vaultIndexService,
                              bedrockClient: _bedrockClient,
                              primaryColor: primaryColor,
                              showStaleBanner:
                                  _indexStale && !_bannerDismissed,
                              onRebuildIndex: _rebuildIndex,
                              onDismissBanner: () => setState(
                                  () => _bannerDismissed = true),
                              initialMessages: List.from(
                                _chatHistory[_currentPaperPath ?? _globalChatKey] ?? [],
                              ),
                              onMessagesChanged: _onChatMessagesChanged,
                            ),

                            // TAB 3: CITATIONS SCREEN
                            CitationsTab(
                              citations: paperCitations,
                              primaryColor: primaryColor,
                            ),

                            // TAB 4: VAULT LIBRARY
                            LibraryTab(
                              key: _libraryTabKey,
                              vaultPath: vaultPath,
                              onOpenPaper: _openPaperFromLibrary,
                              loadLibrary: _loadLibrary,
                              primaryColor: primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
