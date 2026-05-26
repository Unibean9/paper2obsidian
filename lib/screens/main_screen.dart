import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/paper_controller.dart';
import '../models/paper_metadata.dart';
import '../services/api_service.dart';
import '../services/bedrock_client.dart';
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
  bool isLoading = false;
  // NOTE: _isCancelled is NOT in Bucket A — it lives in PaperController.isCancelled (single source of truth)
  String statusText = 'Sẵn sàng';
  String fullPdfText = '';
  List<Map<String, String>> chatMessages = [];
  bool isChatLoading = false;
  List<String> paperCitations = [];
  List<String> progressLogs = [];

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
  late ResearchApiService researchApiService;
  late PaperController _paperController;

  // GlobalKey for triggering LibraryTab refresh after save
  final GlobalKey<LibraryTabState> _libraryTabKey = GlobalKey<LibraryTabState>();

  @override
  void initState() {
    super.initState();
    researchApiService = ResearchApiService(
      grobidUrl: 'http://localhost:8070',
      bedrockClient: BedrockClient(config: BedrockConfig.fromEnvironment()),
    );
    _paperController = PaperController(
      apiService: researchApiService,
      onLog: _addLog,
      // No onStateChange: controller only returns data; screen calls setState after each await
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
      statusText = message; // Giữ lại biến này để đổi màu box (xanh/đỏ)
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
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vaultPath', vaultPath);
    if (!mounted) return; // ← guard before ScaffoldMessenger to prevent use-after-dispose crash
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved settings!')),
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
      _showUserMessage('Select a PDF first.', isError: true);
      return false;
    }
    if (vaultPath.trim().isEmpty) {
      _showUserMessage(
        'Set your Obsidian vault in Settings → Browse (required on macOS).',
        isError: true,
      );
      _showSettingsDialog(context);
      return false;
    }
    final bool vaultExists;
    try {
      vaultExists = await Directory(vaultPath).exists();
    } catch (e) {
      debugPrint(
        '_ensureVaultReady: directory check failed for "$vaultPath": $e',
      );
      _showUserMessage(
        'Cannot access vault path. Use Settings → Browse to select the folder.',
        isError: true,
      );
      return false;
    }
    if (!vaultExists) {
      _showUserMessage(
        'Vault folder not found. Use Settings → Browse to select it again.',
        isError: true,
      );
      return false;
    }

    if (await VaultAccess.canWriteToVault(vaultPath)) return true;

    if (VaultAccess.requiresPickerGrant) {
      _showUserMessage(
        'macOS blocked vault access. Please select the vault folder again.',
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
      'Cannot write to vault. On macOS you must use Browse in Settings — typing the path is not enough.',
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
          'Could not read the selected PDF. Try another file.',
          isError: true,
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        selectedPdf = file;
        statusText = 'Selected: ${p.basename(file.path)}';
        chatMessages.clear();
        fullPdfText = '';
        isLoading = true;
        progressLogs.clear();
      });

      try {
        final PaperMetadata meta = await _paperController.processPdf(file);
        // Guard against cancel: isCancelled means the pipeline was stopped mid-flight
        // and returned PaperMetadata.empty() — do not overwrite already-populated fields.
        if (mounted && !_paperController.isCancelled) {
          _applyMetadata(meta);
          // Khởi tạo chat sau khi trích xuất xong
          setState(() {
            chatMessages.add({
              'role': 'assistant',
              'content':
                  'Hi! I have read the paper. What would you like to know about it?',
            });
          });
        }
      } catch (e) {
        _addLog('❌ PDF extraction error: $e');
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e, stack) {
      debugPrint('PDF picker error: $e\n$stack');
      _showUserMessage('Failed to open file picker: $e', isError: true);
    }
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
        fullPdfText: fullPdfText,
        resolvedPdf: selectedPdf,
      );
      await _paperController.saveToObsidian(
        meta: meta,
        vaultPath: vaultPath,
        pdf: selectedPdf!,
      );
      if (!mounted) return;
      _showUserMessage('Saved to Obsidian!');
      // Refresh the library tab to show the newly saved note
      _libraryTabKey.currentState?.refresh();
    } on FileSystemException catch (e) {
      _showUserMessage(
        'Cannot write to vault. Check folder permissions or re-select it in Settings → Browse.\n\n$e',
        isError: true,
      );
    } catch (e) {
      _showUserMessage('Save failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // =========================================================================
  // LIBRARY
  // =========================================================================

  Future<void> _openPaperFromLibrary(String mdPath) async {
    setState(() {
      isLoading = true;
      progressLogs.clear();
      chatMessages.clear();
    });
    _addLog('📂 Loading paper from library: ${p.basename(mdPath)}');

    try {
      final PaperMetadata meta =
          await _paperController.openPaperFromLibrary(mdPath);
      if (mounted) {
        _applyMetadata(meta);
        setState(() {
          chatMessages.add({
            'role': 'assistant',
            'content':
                'I loaded this paper from your library vault. You can now read it or ask me questions about it!',
          });
        });
      }
    } catch (e) {
      _addLog('❌ $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<List<Map<String, String>>> _loadLibrary() {
    return _paperController.loadVaultLibrary(vaultPath);
  }

  // =========================================================================
  // AI CHAT
  // =========================================================================

  Future<void> _handleSendMessage(String userText) async {
    setState(() {
      chatMessages.add({'role': 'user', 'content': userText});
      isChatLoading = true;
    });
    try {
      final String reply =
          await _paperController.sendChatMessage(userText, fullPdfText);
      if (mounted) {
        setState(() =>
            chatMessages.add({'role': 'assistant', 'content': reply}));
      }
    } catch (e) {
      if (mounted) {
        setState(() => chatMessages
            .add({'role': 'assistant', 'content': 'Error: $e'}));
      }
    } finally {
      if (mounted) setState(() => isChatLoading = false);
    }
  }

  // =========================================================================
  // CANCEL
  // =========================================================================

  /// Cancel handler: stops the controller pipeline AND resets screen loading state.
  void _handleCancel() {
    _paperController.cancel();
    setState(() {
      isLoading = false;
      statusText = 'Đã dừng trích xuất. Bạn có thể chọn file khác.';
    });
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
            // CỘT 1: ACTIONS PANEL
            // ------------------------------------------
            SizedBox(
              width: 260,
              child: ActionsPanel(
                isLoading: isLoading,
                vaultPath: vaultPath,
                selectedPdf: selectedPdf,
                progressLogs: progressLogs,
                statusText: statusText,
                primaryColor: primaryColor,
                onPickPdf: _pickPdf,
                onSaveToObsidian: _saveToObsidian,
                onCancel: _handleCancel,
              ),
            ),

            const SizedBox(width: 20),

            // ------------------------------------------
            // CỘT 2: PDF PREVIEW WITH ZOOM & TEXT INTERACTION TOOLBAR
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
            // CỘT 3: 3-TAB MANAGEMENT PANEL (METADATA, CHAT, VAULT LIBRARY)
            // ------------------------------------------
            Expanded(
              flex: 4,
              child: PanelContainer(
                padding: EdgeInsets.zero,
                child: DefaultTabController(
                  length: 4, // Cấu hình 4 Tab chuyên sâu
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

                            // TAB 2: AI CHAT ASSISTANT
                            ChatTab(
                              chatMessages: chatMessages,
                              fullPdfText: fullPdfText,
                              isChatLoading: isChatLoading,
                              onSendMessage: _handleSendMessage,
                              primaryColor: primaryColor,
                            ),

                            // TAB 3: CITATIONS SCREEN
                            CitationsTab(
                              citations: paperCitations,
                              primaryColor: primaryColor,
                            ),

                            // TAB 4: VAULT LIBRARY SCREEN (MÀN HÌNH THƯ VIỆN)
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
