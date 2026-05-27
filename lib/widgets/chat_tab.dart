import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/bedrock_client.dart';
import '../services/vault_index_service.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({
    super.key,
    required this.vaultIndexService,
    required this.bedrockClient,
    required this.primaryColor,
    this.showStaleBanner = false,
    this.onRebuildIndex,
    this.onDismissBanner,
    this.initialMessages = const [],
    this.onMessagesChanged,
    this.onCitationsUpdated,
    this.indexRevision = 0,
  });

  final VaultIndexService vaultIndexService;
  final BedrockClient bedrockClient;
  final Color primaryColor;

  final bool showStaleBanner;
  final Future<void> Function()? onRebuildIndex;
  final VoidCallback? onDismissBanner;
  final List<Map<String, dynamic>> initialMessages;
  final void Function(List<Map<String, dynamic>> messages)? onMessagesChanged;
  final void Function(List<String> citations)? onCitationsUpdated;
  final int indexRevision;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> with AutomaticKeepAliveClientMixin {
  // Keep state alive when switching tabs so cleared messages are not restored
  // from initialMessages by a fresh initState call.
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

  @override
  void initState() {
    super.initState();
    // Seed from parent-provided history (copy to avoid aliasing).
    _messages = List.from(widget.initialMessages);
    // Load available indexed papers for the scope selector.
    _availablePapers = widget.vaultIndexService.getIndexedPaperTitles();
    // Load persisted language preference; default 'en' used until loaded.
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
    // Reload messages if parent reinitializes (e.g., paper context change)
    if (widget.initialMessages != oldWidget.initialMessages) {
      setState(() {
        _messages = List.from(widget.initialMessages);
      });
    }
  }

  @override
  void dispose() {
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
              ? 'No papers indexed yet. Save a paper first, or go to '
                    'Settings → Re-index Vault.'
              : 'No results found in the selected papers. '
                    'Try expanding the scope or choosing different papers.',
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
          ..writeln(
            '[${i + 1}] Paper: "${chunks[i].paperTitle}" | Section: ${chunks[i].section}',
          )
          ..writeln(chunks[i].text)
          ..writeln();
      }

      final exampleCites = List.generate(
        chunks.length,
        (i) => '[${i + 1}]',
      ).join(', ');

      final langInstruction = _outputLanguage == 'vi'
          ? '\nRespond entirely in Vietnamese.'
          : '';

      final systemPrompt =
          'You are a research assistant.$langInstruction\n'
          'Use ONLY the numbered sources below to answer the question.\n'
          'After each claim or sentence that references a source, cite it '
          'with its number in brackets, e.g. [1] or [2].\n'
          'Available citation numbers: $exampleCites\n'
          'Do NOT add a "Sources:" section at the end — '
          'inline citations are sufficient.\n'
          'If you cannot find an answer in the sources, '
          'say "I don\'t have information on that."\n'
          '\nSOURCES:\n${contextBuf.toString()}';

      final List<Map<String, String>> sourcesList = chunks
          .map((c) => {'title': c.paperTitle, 'section': c.section})
          .toList();

      final citationStrings = chunks
          .asMap()
          .entries
          .map(
            (e) => '[${e.key + 1}] ${e.value.paperTitle} — ${e.value.section}',
          )
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
            ..writeln(
              '[${i + 1}] **${chunks[i].paperTitle}** — ${chunks[i].section}',
            )
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

      _addAssistantMessage(response, sources: sourcesList);
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
  }) {
    if (!mounted) return;
    final msg = <String, dynamic>{'role': 'assistant', 'content': content};
    if (sources != null) msg['sources'] = sources;
    setState(() => _messages.add(msg));
    widget.onMessagesChanged?.call(List.from(_messages));
  }

  void _showScopeSheet() {
    setState(() {
      _availablePapers = widget.vaultIndexService.getIndexedPaperTitles();
    });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PaperScopeSheet(
        availablePapers: _availablePapers,
        selectedPapers: List.from(_selectedPapers),
        onChanged: (selected) {
          setState(() => _selectedPapers = selected);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _clearChat() {
    if (_messages.isEmpty) return;
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return Column(
      children: [
        if (widget.showStaleBanner)
          _StaleBanner(
            isRebuilding: _isRebuilding,
            onRebuild: _handleRebuild,
            onDismiss: widget.onDismissBanner,
            primaryColor: widget.primaryColor,
          ),

        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isUser = msg['role'] == 'user';
              final content = msg['content'] as String? ?? '';
              final sources =
                  (msg['sources'] as List?)
                      ?.map((s) => Map<String, String>.from(s as Map))
                      .toList() ??
                  const [];
              return Align(
                key: ValueKey(index),
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.22,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? widget.primaryColor : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: isUser
                          ? const Radius.circular(0)
                          : const Radius.circular(16),
                      bottomLeft: !isUser
                          ? const Radius.circular(0)
                          : const Radius.circular(16),
                    ),
                  ),
                  child: isUser
                      ? Text(
                          content,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.4,
                          ),
                        )
                      : _AssistantMessageWidget(
                          key: ValueKey('msg_$index'),
                          content: content,
                          sources: sources,
                          primaryColor: widget.primaryColor,
                        ),
                ),
              );
            },
          ),
        ),

        if (_isLoading)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Searching vault…',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),

        const Divider(height: 1),

        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 8,
              children:
                  [
                        'What are the key findings?',
                        'Compare research methodologies',
                        'What limitations are discussed?',
                      ]
                      .map(
                        (s) => ActionChip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          backgroundColor: widget.primaryColor.withValues(
                            alpha: 0.05,
                          ),
                          side: BorderSide(
                            color: widget.primaryColor.withValues(alpha: 0.2),
                          ),
                          onPressed: () => _handleSuggestion(s),
                        ),
                      )
                      .toList(),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              ActionChip(
                avatar: Icon(
                  Icons.filter_list,
                  size: 14,
                  color: _selectedPapers.isEmpty ? null : widget.primaryColor,
                ),
                label: Text(
                  _selectedPapers.isEmpty
                      ? 'All papers'
                      : '${_selectedPapers.length} paper'
                            '${_selectedPapers.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: _selectedPapers.isEmpty
                    ? null
                    : widget.primaryColor.withValues(alpha: 0.08),
                side: _selectedPapers.isEmpty
                    ? null
                    : BorderSide(
                        color: widget.primaryColor.withValues(alpha: 0.3),
                      ),
                onPressed: _showScopeSheet,
              ),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('EN')),
                  ButtonSegment(value: 'vi', label: Text('VI')),
                ],
                selected: {_outputLanguage},
                onSelectionChanged: (s) => _setOutputLanguage(s.first),
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              const Spacer(),
              if (_messages.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.delete_sweep_outlined,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                  tooltip: 'Clear chat',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  onPressed: _isLoading ? null : _clearChat,
                ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  decoration: InputDecoration(
                    hintText: _selectedPapers.isEmpty
                        ? 'Ask across all vault papers…'
                        : 'Ask ${_selectedPapers.length == 1 ? '"${_selectedPapers.first}"' : '${_selectedPapers.length} selected papers'}…',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade200,
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: widget.primaryColor,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  onPressed: _isLoading ? null : _handleSend,
                ),
              ),
            ],
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
    required this.primaryColor,
  });

  final String content;
  final List<Map<String, String>> sources;
  final Color primaryColor;

  @override
  State<_AssistantMessageWidget> createState() =>
      _AssistantMessageWidgetState();
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
    if (oldWidget.content != widget.content ||
        oldWidget.sources != widget.sources) {
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
            style: const TextStyle(color: Colors.black87, height: 1.4),
          ),
        );
      }

      final n = int.tryParse(match.group(1) ?? '') ?? 0;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _showSourceDialog(n);
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: widget.primaryColor,
            decoration: TextDecoration.underline,
            decorationColor: widget.primaryColor,
            height: 1.4,
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
          style: const TextStyle(color: Colors.black87, height: 1.4),
        ),
      );
    }

    return spans;
  }

  void _showSourceDialog(int n) {
    if (!mounted) return;
    final idx = n - 1;
    final source = (idx >= 0 && idx < widget.sources.length)
        ? widget.sources[idx]
        : null;

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Source [$n]'),
        content: source != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source['title'] ?? '(unknown paper)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    source['section'] ?? '(unknown section)',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              )
            : const Text(
                'Source not found. The citation number may be outside the '
                'available sources list.',
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

class _PaperScopeSheet extends StatefulWidget {
  const _PaperScopeSheet({
    required this.availablePapers,
    required this.selectedPapers,
    required this.onChanged,
  });

  final List<String> availablePapers;
  final List<String> selectedPapers;
  final void Function(List<String>) onChanged;

  @override
  State<_PaperScopeSheet> createState() => _PaperScopeSheetState();
}

class _PaperScopeSheetState extends State<_PaperScopeSheet> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedPapers);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scope search to papers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _selected = List.from(widget.availablePapers);
                      }),
                      child: const Text('All'),
                    ),
                    FilledButton(
                      onPressed: () => widget.onChanged(List.from(_selected)),
                      child: const Text('Apply'),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (widget.availablePapers.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'No papers indexed yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: widget.availablePapers.length,
                itemBuilder: (_, i) {
                  final title = widget.availablePapers[i];
                  return CheckboxListTile(
                    title: Text(title, style: const TextStyle(fontSize: 13)),
                    value: _selected.contains(title),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selected.add(title);
                      } else {
                        _selected.remove(title);
                      }
                    }),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({
    required this.isRebuilding,
    required this.onRebuild,
    required this.onDismiss,
    required this.primaryColor,
  });

  final bool isRebuilding;
  final Future<void> Function() onRebuild;
  final VoidCallback? onDismiss;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: Colors.amber.shade800,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Index outdated — some papers may not be searchable.',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
            ),
          ),
          if (isRebuilding)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primaryColor,
              ),
            )
          else
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onRebuild,
              child: Text(
                'Rebuild',
                style: TextStyle(fontSize: 12, color: primaryColor),
              ),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onDismiss,
            color: Colors.amber.shade800,
          ),
        ],
      ),
    );
  }
}
