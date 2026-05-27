import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/bedrock_client.dart';
import '../services/vault_index_service.dart';

/// Tab 2 — Vault-wide RAG chat.
///
/// Owns its own message list and all chat state internally.
/// Queries [VaultIndexService] for top-k relevant chunks, builds an attributed
/// system prompt, and calls [BedrockClient.converse] for a synthesised answer.
/// Falls back to BM25 keyword search when AWS credentials are absent and
/// prepends a visible notice to the response.
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
  });

  final VaultIndexService vaultIndexService;
  final BedrockClient bedrockClient;
  final Color primaryColor;

  /// When true, a staleness warning banner is rendered at the top of the chat area.
  final bool showStaleBanner;

  /// Called when the user taps "Rebuild" in the staleness banner.
  final Future<void> Function()? onRebuildIndex;

  /// Called when the user taps "✕" to dismiss the staleness banner.
  final VoidCallback? onDismissBanner;

  /// Seed messages to display on mount (restored from per-paper history).
  /// The parent copies the list before passing — no aliasing risk.
  final List<Map<String, dynamic>> initialMessages;

  /// Fired whenever the message list changes (user send or assistant reply).
  /// The parent uses this to keep [_chatHistory] in sync for persistence.
  final void Function(List<Map<String, dynamic>> messages)? onMessagesChanged;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _inputCtrl = TextEditingController();

  /// Message type is `Map<String, dynamic>` so Phase 3 can store a `sources`
  /// key alongside `role` and `content` without breaking the history cache.
  late List<Map<String, dynamic>> _messages;
  bool _isLoading = false;
  bool _isRebuilding = false;

  @override
  void initState() {
    super.initState();
    // Seed from parent-provided history (copy to avoid aliasing).
    _messages = List.from(widget.initialMessages);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  // ─── Scroll ────────────────────────────────────────────────────────────────

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

  // ─── Send message ──────────────────────────────────────────────────────────

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
      final result = await widget.vaultIndexService.query(text, topK: 5);

      if (result.chunks.isEmpty) {
        _addAssistantMessage(
          'No papers indexed yet. Save a paper first, or go to '
          'Settings → Re-index Vault.',
        );
        return;
      }

      final seen = <String>{};
      final chunks = result.chunks
          .where((c) => seen.add('${c.paperTitle}::${c.section}'))
          .toList();

      // Build numbered attribution context.
      final contextBuf = StringBuffer();
      for (int i = 0; i < chunks.length; i++) {
        contextBuf
          ..writeln('[${i + 1}] ${chunks[i].paperTitle} | ${chunks[i].section}')
          ..writeln(chunks[i].text)
          ..writeln();
      }

      final exampleCites = List.generate(
        chunks.length,
        (i) => '[${i + 1}]',
      ).join(', ');

      final systemPrompt =
          '''You are a research assistant.
Use ONLY the numbered sources below to answer the question.
After each sentence that uses a source, write its number in brackets.
Example: "Agile teams use sprints [1]. Requirements change frequently [2]."
Available citation numbers: $exampleCites
End your answer with a "Sources:" section that lists every number you cited.
If you cannot find an answer in the sources, say "I don't have information on that."

SOURCES:
${contextBuf.toString()}''';

      // Build the sources list used for clickable citations (Phase 3).
      // Indexed 0-based: sources[0] → [1], sources[1] → [2], etc.
      final sourcesList = chunks
          .map((c) => {'title': c.paperTitle, 'section': c.section})
          .toList();

      String response;
      try {
        response = await widget.bedrockClient.converse(
          systemPrompt: systemPrompt,
          userMessage: text,
        );
      } on BedrockUnconfiguredException {
        // AWS not configured — surface the retrieved context as a plain list
        // rather than showing a raw exception.
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

      // Always strip any model-generated "Sources:" block (may be incomplete)
      // and replace with the app-controlled version that has full paper details.
      final sourcesRe = RegExp(r'\n*Sources:.*$', dotAll: true);
      response = response.replaceFirst(sourcesRe, '').trimRight();

      final sourceLines = StringBuffer('\n\nSources:\n');
      for (int i = 0; i < chunks.length; i++) {
        sourceLines.writeln(
          '[${i + 1}] ${chunks[i].paperTitle} — ${chunks[i].section}',
        );
      }
      response += sourceLines.toString();

      // Prepend BM25 fallback notice when semantic search was unavailable.
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

  /// Adds an assistant message to [_messages] and notifies the parent.
  ///
  /// [sources] is an optional list of `{'title': ..., 'section': ...}` maps
  /// stored alongside the message for Phase 3 clickable citations. When null,
  /// no `sources` key is stored (user/error messages have no citations).
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

  Future<void> _handleSuggestion(String suggestion) async {
    _inputCtrl.text = suggestion;
    await _handleSend();
  }

  // ─── Rebuild banner action ─────────────────────────────────────────────────

  Future<void> _handleRebuild() async {
    setState(() => _isRebuilding = true);
    try {
      await widget.onRebuildIndex?.call();
    } finally {
      if (mounted) setState(() => _isRebuilding = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showStaleBanner)
          _StaleBanner(
            isRebuilding: _isRebuilding,
            onRebuild: _handleRebuild,
            onDismiss: widget.onDismissBanner,
            primaryColor: widget.primaryColor,
          ),

        // Message list
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isUser = msg['role'] == 'user';
              final content = msg['content'] as String? ?? '';
              final sources = (msg['sources'] as List?)
                      ?.map((s) => Map<String, String>.from(s as Map))
                      .toList() ??
                  const [];
              return Align(
                // ValueKey prevents Flutter from swapping recognizer State
                // between messages when the list scrolls out of view.
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

        // Thinking indicator
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

        // Quick suggestions
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

        // Input row
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ask across all vault papers…',
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

// ─── Assistant message bubble with clickable [N] citations ────────────────

/// Renders an assistant message as [RichText] with tappable `[N]` citation
/// markers. Each tap opens an [AlertDialog] showing the referenced paper title
/// and section from the companion [sources] list.
///
/// Owns a [List<TapGestureRecognizer>] that is fully disposed in [dispose],
/// preventing Flutter framework "pending gesture" debug errors.
/// Each instance in [ListView.builder] carries a [ValueKey] so Flutter's
/// element reconciliation never swaps recognizer state between messages.
class _AssistantMessageWidget extends StatefulWidget {
  const _AssistantMessageWidget({
    required super.key,
    required this.content,
    required this.sources,
    required this.primaryColor,
  });

  final String content;

  /// Parallel list to the `[1]`, `[2]` … markers: `sources[0]` → `[1]`.
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

  /// Splits [widget.content] into alternating plain-text and `[N]` spans.
  /// Creates one [TapGestureRecognizer] per citation token; stores them in
  /// [_recognizers] so they can be disposed correctly.
  List<TextSpan> _buildSpans() {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\[(\d+)\]');
    var lastEnd = 0;

    for (final match in pattern.allMatches(widget.content)) {
      // Plain text segment before this citation token.
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: widget.content.substring(lastEnd, match.start),
          style: const TextStyle(color: Colors.black87, height: 1.4),
        ));
      }

      final n = int.tryParse(match.group(1) ?? '') ?? 0;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _showSourceDialog(n);
      _recognizers.add(recognizer);

      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          color: widget.primaryColor,
          decoration: TextDecoration.underline,
          decorationColor: widget.primaryColor,
          height: 1.4,
        ),
        recognizer: recognizer,
      ));
      lastEnd = match.end;
    }

    // Remaining plain text after the last citation token.
    if (lastEnd < widget.content.length) {
      spans.add(TextSpan(
        text: widget.content.substring(lastEnd),
        style: const TextStyle(color: Colors.black87, height: 1.4),
      ));
    }

    return spans;
  }

  void _showSourceDialog(int n) {
    if (!mounted) return;
    final idx = n - 1; // sources is 0-indexed; [1] → index 0
    final source =
        (idx >= 0 && idx < widget.sources.length) ? widget.sources[idx] : null;

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
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
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
    return RichText(
      text: TextSpan(children: _spans),
    );
  }
}

// ─── Staleness banner ──────────────────────────────────────────────────────

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
