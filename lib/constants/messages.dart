enum MessageKey {
  // --- Status: PDF processing pipeline ---
  statusStep1Extracting,
  statusStep2Grobid,
  statusStep3OpenAlex,
  statusStep4Bedrock,
  statusAllDone,
  statusGrobidNoTitle,
  statusGrobidUnavailable,
  statusOpenAlexNoMatch,
  statusOpenAlexSkippedTitle,
  statusBedrockRetryOpenAlex,
  statusOpenAlexMatchedBedrock,

  // --- Status: UI feedback ---
  statusReady,
  statusSavedToObsidian,
  statusSettingsSaved,
  statusCancelled,

  // --- Error ---
  errorSelectPdfFirst,
  errorSetVaultPath,
  errorVaultAccessFailed,
  errorVaultNotFound,
  errorMacosVaultBlocked,
  errorVaultWriteDenied,
  errorPdfReadFailed,

  // --- Chat ---
  chatInitialGreeting,
  chatLibraryGreeting,
  chatEmptyState,
  chatThinking,
  chatInputHint,
  chatSuggestionNovelty,
  chatSuggestionResearchGap,
  chatSuggestionLimitation,

  // --- Library ---
  libraryRefreshTooltip,
  libraryEmpty,

  // --- Settings ---
  settingsVaultHint,
  settingsBrowseButton,
  settingsSaveButton,

  // --- General ---
  appTitle,
  labelSavedNotes,
}

class AppMessages {
  AppMessages._();

  static const Map<MessageKey, String> _map = {
    // Processing pipeline status
    MessageKey.statusStep1Extracting: '⏳ Step 1/4: Extracting text from PDF...',
    MessageKey.statusStep2Grobid:
        '⏳ Step 2/4: Parsing structure with Grobid...',
    MessageKey.statusStep3OpenAlex:
        '⏳ Step 3/4: Fetching precise OpenAlex metadata...',
    MessageKey.statusStep4Bedrock:
        '⏳ Step 4/4: Extracting metadata & summary with AWS Bedrock...',
    MessageKey.statusAllDone: '🎉 Success! All data extracted and merged.',
    MessageKey.statusGrobidNoTitle:
        'ℹ️ Grobid: no title in PDF structure (will infer from text).',
    MessageKey.statusGrobidUnavailable:
        'ℹ️ Grobid unavailable — continuing with text/Bedrock only.',
    MessageKey.statusOpenAlexNoMatch:
        'ℹ️ OpenAlex: no match for this title (non-academic PDF is OK).',
    MessageKey.statusOpenAlexSkippedTitle:
        'ℹ️ OpenAlex skipped (title not suitable for academic search).',
    MessageKey.statusBedrockRetryOpenAlex:
        'ℹ️ Retrying OpenAlex with Bedrock title…',
    MessageKey.statusOpenAlexMatchedBedrock:
        '✅ OpenAlex matched after Bedrock title.',

    // UI feedback
    MessageKey.statusReady: 'Ready',
    MessageKey.statusSavedToObsidian: 'Saved to Obsidian!',
    MessageKey.statusSettingsSaved: 'Saved settings!',
    MessageKey.statusCancelled:
        'Extraction stopped. You can select another file.',

    // Errors
    MessageKey.errorSelectPdfFirst: 'Select a PDF first.',
    MessageKey.errorSetVaultPath:
        'Set your Obsidian vault in Settings → Browse (required on macOS).',
    MessageKey.errorVaultAccessFailed:
        'Cannot access vault path. Use Settings → Browse to select the folder.',
    MessageKey.errorVaultNotFound:
        'Vault folder not found. Use Settings → Browse to select it again.',
    MessageKey.errorMacosVaultBlocked:
        'macOS blocked vault access. Please select the vault folder again.',
    MessageKey.errorVaultWriteDenied:
        'Cannot write to vault. On macOS you must use Browse in Settings'
        ' — typing the path is not enough.',
    MessageKey.errorPdfReadFailed:
        'Could not read the selected PDF. Try another file.',

    // Chat
    MessageKey.chatInitialGreeting:
        'Hi! I have read the paper. What would you like to know about it?',
    MessageKey.chatLibraryGreeting:
        'I loaded this paper from your library vault.'
        ' You can now read it or ask me questions about it!',
    MessageKey.chatEmptyState: 'Select a PDF to start chatting.',
    MessageKey.chatThinking: 'AI is thinking...',
    MessageKey.chatInputHint: 'Ask about this paper...',
    MessageKey.chatSuggestionNovelty: 'What is the novelty of this paper?',
    MessageKey.chatSuggestionResearchGap: 'What is the research gap?',
    MessageKey.chatSuggestionLimitation: 'What are the limitations?',

    // Library
    MessageKey.libraryRefreshTooltip: 'Refresh library',
    MessageKey.libraryEmpty: 'Library is empty.',

    // Settings
    MessageKey.settingsVaultHint: 'Obsidian vault path',
    MessageKey.settingsBrowseButton: 'Browse',
    MessageKey.settingsSaveButton: 'Save',

    // General
    MessageKey.appTitle: 'Paper to Obsidian',
    MessageKey.labelSavedNotes: 'Saved Notes',
  };

  static String get(MessageKey key) => _map[key]!;

  static String statusTextExtracted(int chars) =>
      '✅ Text extracted ($chars chars).';

  static String statusGrobidSuccess(int authorCount) =>
      '✅ Grobid success: Found Title & $authorCount authors.';

  static String statusTitleForSearch(String title) =>
      'ℹ️ Title for search: $title';

  static String statusOpenAlexSuccess(String doi) =>
      '✅ OpenAlex success: Found DOI ($doi) and Venue.';

  static String statusOpenAlexSkippedError(Object error) =>
      'ℹ️ OpenAlex skipped: $error';

  static String statusBedrockSuccess() =>
      '✅ Bedrock success: Extracted extra details.';

  static String statusBedrockError(Object error) => '⚠️ Bedrock error: $error';

  static String statusPdfFound(String filename) => '✅ PDF found: $filename';

  static String statusSelectedPdf(String filename) => 'Selected: $filename';

  static String statusLoadingPaper(String filename) =>
      '📂 Loading paper from library: $filename';

  static String errorPdfExtraction(Object error) =>
      '❌ PDF extraction error: $error';

  static String errorChat(Object error) => 'Error: $error';

  static String errorSavePermission(Object error) =>
      'Cannot write to vault. Check folder permissions or re-select it'
      ' in Settings → Browse.\n\n$error';

  static String errorSaveFailed(Object error) => 'Save failed: $error';

  static String errorFilePickerFailed(Object error) =>
      'Failed to open file picker: $error';

  static String errorLibraryItem(Object error) => '❌ $error';

  static String labelSavedNotesCount(int count) => 'Saved Notes ($count)';
}
