import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/animated_dialog.dart';
import '../../services/bedrock_client.dart';
import '../../services/vault_index_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({
    super.key,
    required this.vaultIndexService,
    required this.bedrockClient,
    this.showStaleBanner = false,
    this.onRebuildIndex,
    this.onDismissBanner,
    this.initialMessages = const [],
    this.onMessagesChanged,
    this.onCitationsUpdated,
    this.indexRevision = 0,
    this.onCollapse,
  });

  final VaultIndexService vaultIndexService;
  final BedrockClient bedrockClient;

  final bool showStaleBanner;
  final Future<void> Function()? onRebuildIndex;
  final VoidCallback? onDismissBanner;
  final List<Map<String, dynamic>> initialMessages;
  final void Function(List<Map<String, dynamic>> messages)? onMessagesChanged;
  final void Function(List<String> citations)? onCitationsUpdated;
  final int indexRevision;
  final VoidCallback? onCollapse;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _inputCtrl = TextEditingController();

  late List<Map<String, dynamic>> _messages;
  bool _isLoading = false;
  bool _isRebuilding = false;

  List<String> _selectedPapers = [];
  List<String> _availablePapers = [];
  String _outputLanguage = 'en';

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.initialMessages);
    _availablePapers = widget.vaultIndexService.getIndexedPaperTitles();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _outputLanguage = prefs.getString('chat_output_language') ?? 'en';
      });
    });
  }

  @override
  void didUpdateWidget(covariant ChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.indexRevision != oldWidget.indexRevision) {
      setState(() {
        _availablePapers = widget.vaultIndexService.getIndexedPaperTitles();
      });
    }
    if (widget.initialMessages != oldWidget.initialMessages) {
      setState(() {
        _messages = List.from(widget.initialMessages);
      });
    }
  }

  @override
  void dispose() {
    _closeDropdown();
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleSend() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isLoading) return;
    _inputCtrl.clear();

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    widget.onMessagesChanged?.call(List.from(_messages));
    _scrollToBottom();

    try {
      final result = await widget.vaultIndexService.query(
        text,
        topK: 5,
        paperFilter: _selectedPapers.isEmpty ? null : _selectedPapers,
      );

      if (result.chunks.isEmpty) {
        _addAssistantMessage(
          _selectedPapers.isEmpty
              ? 'No papers indexed yet. Save a paper first, or go to Settings → Re-index Vault.'
              : 'No results found in the selected papers. Try expanding the scope or choosing different papers.',
        );
        return;
      }

      final seen = <String>{};
      final chunks = result.chunks
          .where((c) => seen.add('${c.paperTitle}::${c.section}'))
          .toList();

      final contextBuf = StringBuffer();
      for (int i = 0; i < chunks.length; i++) {
        contextBuf
          ..writeln('[${i + 1}] Paper: "${chunks[i].paperTitle}" | Section: ${chunks[i].section}')
          ..writeln(chunks[i].text)
          ..writeln();
      }

      final exampleCites = List.generate(chunks.length, (i) => '[${i + 1}]').join(', ');

      final systemPrompt =
          'You are a research assistant.\n'
          'Use ONLY the numbered sources below to answer the question.\n'
          'After each claim or sentence that references a source, cite it '
          'with its number in brackets, e.g. [1] or [2].\n'
          'Available citation numbers: $exampleCites\n'
          'Do NOT add a "Sources:" section at the end — inline citations are sufficient.\n'
          'If you cannot find an answer in the sources, say "I don\'t have information on that."\n'
          '\nSOURCES:\n${contextBuf.toString()}';

      final List<Map<String, String>> sourcesList = chunks
          .map((c) => {'title': c.paperTitle, 'section': c.section})
          .toList();

      final citationStrings = chunks
          .asMap()
          .entries
          .map((e) => '[${e.key + 1}] ${e.value.paperTitle} — ${e.value.section}')
          .toList();
      widget.onCitationsUpdated?.call(citationStrings);

      String response;
      try {
        response = await widget.bedrockClient.converse(
          systemPrompt: systemPrompt,
          userMessage: text,
        );
      } on BedrockUnconfiguredException {
        final buf = StringBuffer(
          '⚠️ AWS Bedrock is not configured — cannot synthesise an answer.\n\n'
          'Relevant sources found in vault:\n\n',
        );
        for (int i = 0; i < chunks.length; i++) {
          buf
            ..writeln('[${i + 1}] **${chunks[i].paperTitle}** — ${chunks[i].section}')
            ..writeln(chunks[i].text)
            ..writeln();
        }
        _addAssistantMessage(buf.toString(), sources: sourcesList);
        return;
      }

      final sourcesRe = RegExp(r'\n*Sources:.*$', dotAll: true);
      response = response.replaceFirst(sourcesRe, '').trimRight();

      if (result.usedFallback) {
        response =
            '⚠️ Semantic search unavailable — keyword search used. '
            'Configure AWS credentials for better results.\n\n$response';
      }

      String? translatedContent;
      if (_outputLanguage == 'vi') {
        try {
          final translationPrompt = 
              'You are an expert academic translator specializing in computer science and scientific papers.\n'
              'Translate the following research assistant response ENTIRELY into natural, fluent, and grammatically correct Vietnamese (Tiếng Việt).\n'
              'CRITICAL RULES:\n'
              '1. Keep all in-text citation brackets EXACTLY as they are (e.g. [1], [2], [1, 2]) and do NOT translate or remove them.\n'
              '2. Preserve formatting, lists, bold text, and line breaks.\n'
              '3. Do NOT add any introductory or concluding comments like "Here is the translation:". Just output the translated text.\n'
              '4. Keep technical terms in English if they are widely used (e.g. "transformer", "neural network", "embeddings") but translate the surrounding explanation to Vietnamese.\n'
              '\nTEXT TO TRANSLATE:\n$response';

          translatedContent = await widget.bedrockClient.converse(
            systemPrompt: 'You are a professional translator. Output only the direct translation.',
            userMessage: translationPrompt,
            temperature: 0.1,
          );
          translatedContent = translatedContent.trim();
        } catch (e) {
          translatedContent = '⚠️ Tự động dịch lỗi: $e';
        }
      }

      _addAssistantMessage(
        response,
        sources: sourcesList,
        translatedContent: translatedContent,
        showTranslation: _outputLanguage == 'vi',
      );
    } catch (e) {
      _addAssistantMessage('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _addAssistantMessage(
    String content, {
    List<Map<String, String>>? sources,
    String? translatedContent,
    bool showTranslation = false,
  }) {
    if (!mounted) return;
    final msg = <String, dynamic>{
      'role': 'assistant',
      'content': content,
      if (showTranslation) 'show_translation': showTranslation,
    };
    if (translatedContent != null) {
      msg['translated_content'] = translatedContent;
    }
    if (sources != null) msg['sources'] = sources;
    setState(() => _messages.add(msg));
    widget.onMessagesChanged?.call(List.from(_messages));
  }

  void _toggleDropdown() {
    if (_overlayEntry != null) {
      _closeDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    if (!mounted) return;
    setState(() {
      _availablePapers = widget.vaultIndexService.getIndexedPaperTitles();
    });
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {}); // Rebuild to rotate selector arrow
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() {}); // Rebuild to restore selector arrow
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _closeDropdown,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(color: Colors.transparent),
              ),
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topLeft,
                followerAnchor: Alignment.bottomLeft,
                offset: const Offset(0, -6),
                child: Material(
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: AppColors.surfaceLight,
                  child: Container(
                    width: 280,
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: StatefulBuilder(
                      builder: (context, setOverlayState) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm + 2,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Scope search',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          setOverlayState(() {
                                            _selectedPapers = List.from(_availablePapers);
                                          });
                                          setState(() {});
                                        },
                                        child: Text(
                                          'All',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.accent,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      GestureDetector(
                                        onTap: () {
                                          setOverlayState(() {
                                            _selectedPapers.clear();
                                          });
                                          setState(() {});
                                        },
                                        child: Text(
                                          'Clear',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            if (_availablePapers.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Text(
                                  'No papers indexed yet.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              )
                            else
                              Flexible(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _availablePapers.length,
                                  itemBuilder: (context, i) {
                                    final title = _availablePapers[i];
                                    final isSelected = _selectedPapers.contains(title);
                                    return InkWell(
                                      onTap: () {
                                        setOverlayState(() {
                                          if (isSelected) {
                                            _selectedPapers.remove(title);
                                          } else {
                                            _selectedPapers.add(title);
                                          }
                                        });
                                        setState(() {});
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.md,
                                          vertical: AppSpacing.sm + 2,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isSelected
                                                  ? Icons.check_box_rounded
                                                  : Icons.check_box_outline_blank_rounded,
                                              size: 16,
                                              color: isSelected ? AppColors.accent : AppColors.textMuted,
                                            ),
                                            const SizedBox(width: AppSpacing.sm),
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  fontSize: 12,
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _clearChat() {
    if (_messages.isEmpty) return;
    showAnimatedDialog<bool>(
      context: context,
      child: AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text(
          'All messages in this conversation will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed != true || !mounted) return;
      setState(() => _messages.clear());
      widget.onMessagesChanged?.call(const []);
    });
  }

  void _setOutputLanguage(String lang) {
    setState(() => _outputLanguage = lang);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('chat_output_language', lang),
    );
  }

  Future<void> _handleRebuild() async {
    setState(() => _isRebuilding = true);
    try {
      await widget.onRebuildIndex?.call();
    } finally {
      if (mounted) setState(() => _isRebuilding = false);
    }
  }

  void _handleSuggestion(String suggestion) {
    _inputCtrl.text = suggestion;
    _handleSend();
  }

  int _getLastAssistantMessageIndex() {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i]['role'] == 'assistant') {
        return i;
      }
    }
    return -1;
  }

  Future<void> _translateMessage(int index) async {
    final msg = _messages[index];
    final content = msg['content'] as String;

    setState(() {
      msg['is_translating'] = true;
      msg['show_translation'] = true;
    });

    try {
      final translationPrompt = 
          'You are an expert academic translator specializing in computer science and scientific papers.\n'
          'Translate the following research assistant response ENTIRELY into natural, fluent, and grammatically correct Vietnamese (Tiếng Việt).\n'
          'CRITICAL RULES:\n'
          '1. Keep all in-text citation brackets EXACTLY as they are (e.g. [1], [2], [1, 2]) and do NOT translate or remove them.\n'
          '2. Preserve formatting, lists, bold text, and line breaks.\n'
          '3. Do NOT add any introductory or concluding comments like "Here is the translation:". Just output the translated text.\n'
          '4. Keep technical terms in English if they are widely used (e.g. "transformer", "neural network", "embeddings") but translate the surrounding explanation to Vietnamese.\n'
          '\nTEXT TO TRANSLATE:\n$content';

      final translated = await widget.bedrockClient.converse(
        systemPrompt: 'You are a professional translator. Output only the direct translation.',
        userMessage: translationPrompt,
        temperature: 0.1,
      );

      if (mounted) {
        setState(() {
          msg['translated_content'] = translated.trim();
          msg['is_translating'] = false;
        });
        widget.onMessagesChanged?.call(List.from(_messages));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          msg['is_translating'] = false;
          msg['translated_content'] = '⚠️ Lỗi dịch thuật: $e';
        });
      }
    }
  }

  Widget _buildTranslationActionBar(int index) {
    final theme = Theme.of(context);
    final msg = _messages[index];
    final isTranslating = msg['is_translating'] == true;
    final hasTranslation = msg['translated_content'] != null;
    final showTranslation = msg['show_translation'] == true;

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm, top: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isTranslating) ...[
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Đang dịch...',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: AppColors.accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (hasTranslation) ...[
            GestureDetector(
              onTap: () {
                setState(() {
                  msg['show_translation'] = !showTranslation;
                });
                widget.onMessagesChanged?.call(List.from(_messages));
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showTranslation ? Icons.g_translate_rounded : Icons.translate_rounded,
                      size: 12,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      showTranslation ? 'Xem bản gốc (EN)' : 'Xem bản dịch (VI)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: () => _translateMessage(index),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.translate_rounded,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Dịch sang Tiếng Việt',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedPaperChip(BuildContext context, String title) {
    final theme = Theme.of(context);
    final displayTitle = title.length > 15 ? '${title.substring(0, 12)}...' : title;

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.description_outlined,
            size: 11,
            color: AppColors.accent,
          ),
          const SizedBox(width: 4),
          Text(
            displayTitle,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10.5,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedPapers.remove(title);
              });
              if (_overlayEntry != null) {
                _closeDropdown();
                _showDropdown();
              }
            },
            child: const MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(
                Icons.close_rounded,
                size: 11,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlusNChip(BuildContext context, int count) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceNeutral,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '+$count',
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, BoxConstraints constraints) {
    final theme = Theme.of(context);
    final papersCount = _availablePapers.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.hero,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * 0.85,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      size: 24,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Research Assistant',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                papersCount > 0
                    ? 'I can help you analyze, compare, and extract insights from your indexed papers.'
                    : 'Import papers in the Library tab or rebuild your vault index in Preferences to start chatting.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              if (papersCount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                    boxShadow: AppShadows.subtle,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.folder_special_outlined,
                            size: 16,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Indexed Papers ($papersCount)',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ..._availablePapers.take(3).map((title) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 5),
                                  child: Icon(
                                    Icons.circle,
                                    size: 4,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )),
                      if (papersCount > 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, left: 12),
                          child: Text(
                            'and ${papersCount - 3} more papers...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              fontStyle: FontStyle.italic,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              if (papersCount > 0) ...[
                Text(
                  'Start with one of these questions:',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...[
                  'What are the key findings?',
                  'Compare research methodologies',
                  'What limitations are discussed?',
                ].map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _handleSuggestion(s),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceNeutral.withValues(alpha: 0.4),
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // AI Chat Header with Trash Icon and Language Selector
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceLight,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'AI Chat',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Tooltip(
                message: 'Clear conversation',
                child: GestureDetector(
                  onTap: (_isLoading || _messages.isEmpty) ? null : _clearChat,
                  child: MouseRegion(
                    cursor: (_isLoading || _messages.isEmpty)
                        ? SystemMouseCursors.basic
                        : SystemMouseCursors.click,
                    child: Icon(
                      Icons.delete,
                      size: 18,
                      color: (_isLoading || _messages.isEmpty)
                          ? AppColors.textMuted
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              PopupMenuButton<String>(
                tooltip: 'Select response language',
                padding: EdgeInsets.zero,
                onSelected: _setOutputLanguage,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.language_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _outputLanguage.toLowerCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'en',
                    child: Text('English (en)', style: theme.textTheme.bodyMedium),
                  ),
                  PopupMenuItem(
                    value: 'vi',
                    child: Text('Tiếng Việt (vi)', style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
              if (widget.onCollapse != null) ...[
                const SizedBox(width: AppSpacing.lg),
                Tooltip(
                  message: 'Thu gọn chat',
                  child: GestureDetector(
                    onTap: widget.onCollapse,
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(
                        Icons.keyboard_double_arrow_right,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.showStaleBanner)
          _StaleBanner(
            isRebuilding: _isRebuilding,
            onRebuild: _handleRebuild,
            onDismiss: widget.onDismissBanner,
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (_messages.isEmpty) {
                return _buildEmptyState(context, constraints);
              }
              final lastAssistantIndex = _getLastAssistantMessageIndex();
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final role = msg['role'] as String;
                  final content = msg['content'] as String;
                  final isUser = role == 'user';
                  final sources = (msg['sources'] as List?)
                          ?.map((e) => Map<String, String>.from(e as Map))
                          .toList() ??
                      [];
                  final showTranslation = msg['show_translation'] == true;
                  final displayContent = showTranslation
                      ? (msg['translated_content'] as String? ?? content)
                      : content;

                  return Padding(
                    key: ValueKey(index),
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser) ...[
                          Container(
                            margin: const EdgeInsets.only(right: AppSpacing.sm, top: 4),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.auto_awesome,
                                size: 13,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSpacing.md,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * 0.82,
                                ),
                                decoration: BoxDecoration(
                                  color: isUser ? AppColors.primary : AppColors.surfaceLight,
                                  border: isUser
                                      ? null
                                      : Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                                  borderRadius: BorderRadius.circular(AppRadius.md).copyWith(
                                    bottomRight: isUser
                                        ? Radius.zero
                                        : const Radius.circular(AppRadius.md),
                                    bottomLeft: !isUser
                                        ? Radius.zero
                                        : const Radius.circular(AppRadius.md),
                                  ),
                                  boxShadow: isUser ? null : AppShadows.subtle,
                                ),
                                child: isUser
                                    ? Text(
                                        content,
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          color: AppColors.textInverse,
                                          height: 1.4,
                                        ),
                                      )
                                    : _AssistantMessageWidget(
                                        key: ValueKey('msg_${index}_$showTranslation'),
                                        content: displayContent,
                                        sources: sources,
                                      ),
                              ),
                              if (!isUser) ...[
                                const SizedBox(height: 4),
                                _buildTranslationActionBar(index),
                              ],
                              if (!isUser && index == lastAssistantIndex && !_isLoading) ...[
                                const SizedBox(height: AppSpacing.md),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth * 0.82,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      'What are the key findings?',
                                      'Compare research methodologies',
                                      'What limitations are discussed?',
                                    ].map((s) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: InkWell(
                                        onTap: () => _handleSuggestion(s),
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceNeutral.withValues(alpha: 0.4),
                                            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
                                            borderRadius: BorderRadius.circular(AppRadius.md),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  s,
                                                  style: theme.textTheme.bodyMedium?.copyWith(
                                                    fontSize: 13,
                                                    color: AppColors.textPrimary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: AppSpacing.sm),
                                              const Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 14,
                                                color: AppColors.textMuted,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Searching vault…',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
              boxShadow: AppShadows.subtle,
            ),
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _inputCtrl,
                  maxLines: null,
                  minLines: 1,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: _selectedPapers.isEmpty
                        ? 'Ask across all vault papers…'
                        : 'Ask ${_selectedPapers.length == 1 ? '"${_selectedPapers.first}"' : '${_selectedPapers.length} papers'}…',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    filled: false,
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    CompositedTransformTarget(
                      link: _layerLink,
                      child: GestureDetector(
                        onTap: _toggleDropdown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceNeutral,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 14,
                                color: _selectedPapers.isEmpty ? AppColors.textSecondary : AppColors.accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _selectedPapers.isEmpty ? 'All papers' : 'Papers',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _overlayEntry != null
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_selectedPapers.isNotEmpty) ...[
                      _buildSelectedPaperChip(context, _selectedPapers[0]),
                      if (_selectedPapers.length > 1)
                        _buildSelectedPaperChip(context, _selectedPapers[1]),
                      if (_selectedPapers.length > 2)
                        _buildPlusNChip(context, _selectedPapers.length - 2),
                    ],
                    const Spacer(),
                    GestureDetector(
                      onTap: _isLoading ? null : _handleSend,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isLoading ? AppColors.textMuted : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: AppColors.textInverse,
                          size: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AssistantMessageWidget extends StatefulWidget {
  const _AssistantMessageWidget({
    required super.key,
    required this.content,
    required this.sources,
  });

  final String content;
  final List<Map<String, String>> sources;

  @override
  State<_AssistantMessageWidget> createState() => _AssistantMessageWidgetState();
}

class _AssistantMessageWidgetState extends State<_AssistantMessageWidget> {
  final List<TapGestureRecognizer> _recognizers = [];
  late List<TextSpan> _spans;

  @override
  void initState() {
    super.initState();
    _spans = _buildSpans();
  }

  @override
  void didUpdateWidget(covariant _AssistantMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content || oldWidget.sources != widget.sources) {
      _disposeRecognizers();
      _spans = _buildSpans();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  List<TextSpan> _buildSpans() {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\[(\d+)\]');
    var lastEnd = 0;

    for (final match in pattern.allMatches(widget.content)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: widget.content.substring(lastEnd, match.start),
            style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
          ),
        );
      }

      final n = int.tryParse(match.group(1) ?? '') ?? 0;
      final recognizer = TapGestureRecognizer()..onTap = () => _showSourceDialog(n);
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            color: AppColors.accent,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.accent,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
          recognizer: recognizer,
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < widget.content.length) {
      spans.add(
        TextSpan(
          text: widget.content.substring(lastEnd),
          style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
        ),
      );
    }

    return spans;
  }

  void _showSourceDialog(int n) {
    if (!mounted) return;
    final idx = n - 1;
    final source = (idx >= 0 && idx < widget.sources.length) ? widget.sources[idx] : null;

    showAnimatedDialog<void>(
      context: context,
      child: AlertDialog(
        title: Text('Source [$n]'),
        content: source != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source['title'] ?? '(unknown paper)',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    source['section'] ?? '(unknown section)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )
            : const Text(
                'Source not found. The citation number may be outside the available sources list.',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RichText(text: TextSpan(children: _spans));
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({
    required this.isRebuilding,
    required this.onRebuild,
    required this.onDismiss,
  });

  final bool isRebuilding;
  final Future<void> Function() onRebuild;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warningSurface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Index outdated — some papers may not be searchable.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
            ),
          ),
          if (isRebuilding)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 0,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onRebuild,
              child: Text(
                'Rebuild',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onDismiss,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}
