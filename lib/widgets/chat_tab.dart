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

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _inputCtrl = TextEditingController();

  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isRebuilding = false;

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

      // De-duplicate: keep one chunk per paper title to avoid one paper
      // dominating all top-k slots when multiple papers are available.
      final seen = <String>{};
      final chunks =
          result.chunks.where((c) => seen.add(c.paperTitle)).toList();

      // Build numbered attribution context.
      final contextBuf = StringBuffer();
      for (int i = 0; i < chunks.length; i++) {
        contextBuf
          ..writeln('[${i + 1}] ${chunks[i].paperTitle} | ${chunks[i].section}')
          ..writeln(chunks[i].text)
          ..writeln();
      }

      final systemPrompt = '''You are a research assistant.
Answer using ONLY the provided sources below.
After each claim cite the source as [N].
End your response with a "Sources:" block listing every cited source.
If a claim has no source, say "I don't have information on that."

${contextBuf.toString()}''';

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
            ..writeln('[${i + 1}] **${chunks[i].paperTitle}** — ${chunks[i].section}')
            ..writeln(chunks[i].text)
            ..writeln();
        }
        _addAssistantMessage(buf.toString());
        return;
      }

      // Ensure a Sources block is always present.
      if (!response.contains('Sources:') && !response.contains('[1]')) {
        final sourceLines = StringBuffer('\n\nSources:\n');
        for (int i = 0; i < chunks.length; i++) {
          sourceLines.writeln('[${i + 1}] ${chunks[i].paperTitle} — ${chunks[i].section}');
        }
        response += sourceLines.toString();
      }

      // Prepend BM25 fallback notice when semantic search was unavailable.
      if (result.usedFallback) {
        response =
            '⚠️ Semantic search unavailable — keyword search used. '
            'Configure AWS credentials for better results.\n\n$response';
      }

      _addAssistantMessage(response);
    } catch (e) {
      _addAssistantMessage('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _addAssistantMessage(String content) {
    if (!mounted) return;
    setState(() => _messages.add({'role': 'assistant', 'content': content}));
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
        if (widget.showStaleBanner) _StaleBanner(
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
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.22,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? widget.primaryColor
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: isUser
                          ? const Radius.circular(0)
                          : const Radius.circular(16),
                      bottomLeft: !isUser
                          ? const Radius.circular(0)
                          : const Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    msg['content']!,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
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
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
              children: [
                'What are the key findings?',
                'Compare research methodologies',
                'What limitations are discussed?',
              ].map((s) => ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    backgroundColor:
                        widget.primaryColor.withValues(alpha: 0.05),
                    side: BorderSide(
                        color: widget.primaryColor.withValues(alpha: 0.2)),
                    onPressed: () => _handleSuggestion(s),
                  )).toList(),
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
                        horizontal: 16, vertical: 12),
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
                  icon:
                      const Icon(Icons.send, color: Colors.white, size: 18),
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
          Icon(Icons.warning_amber_rounded,
              size: 16, color: Colors.amber.shade800),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onRebuild,
              child: Text('Rebuild',
                  style: TextStyle(fontSize: 12, color: primaryColor)),
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
