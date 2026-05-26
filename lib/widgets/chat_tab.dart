import 'package:flutter/material.dart';

import '../constants/messages.dart';

/// Tab 2 — AI Chat assistant for discussing the loaded paper.
/// Owns its own ScrollController and input TextEditingController (Bucket C).
/// The parent screen owns chatMessages and fullPdfText state.
class ChatTab extends StatefulWidget {
  const ChatTab({
    super.key,
    required this.chatMessages,
    required this.fullPdfText,
    required this.isChatLoading,
    required this.onSendMessage,
    required this.primaryColor,
  });

  final List<Map<String, String>> chatMessages;
  final String fullPdfText;
  final bool isChatLoading;

  /// Called when the user sends a message. The widget manages its own input controller.
  final Future<void> Function(String userText) onSendMessage;

  final Color primaryColor;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final ScrollController _chatScrollCtrl = ScrollController();
  final TextEditingController _chatInputCtrl = TextEditingController();

  @override
  void dispose() {
    _chatScrollCtrl.dispose();
    _chatInputCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to bottom when new messages arrive.
    if (widget.chatMessages.length != oldWidget.chatMessages.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend() async {
    final String text = _chatInputCtrl.text.trim();
    if (text.isEmpty || widget.fullPdfText.isEmpty) return;
    _chatInputCtrl.clear();
    await widget.onSendMessage(text);
  }

  Future<void> _handleSuggestion(String suggestion) async {
    _chatInputCtrl.text = suggestion;
    await _handleSend();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullPdfText.isEmpty) {
      return Center(
        child: Text(
          AppMessages.get(MessageKey.chatEmptyState),
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return Column(
      children: [
        // Danh sách tin nhắn
        Expanded(
          child: ListView.builder(
            controller: _chatScrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: widget.chatMessages.length,
            itemBuilder: (context, index) {
              final Map<String, String> msg = widget.chatMessages[index];
              final bool isUser = msg['role'] == 'user';
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
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

        // Indicator khi AI đang xử lý
        if (widget.isChatLoading)
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
                  AppMessages.get(MessageKey.chatThinking),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

        const Divider(height: 1),

        // Gợi ý câu hỏi nhanh
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 8,
              children: [
                AppMessages.get(MessageKey.chatSuggestionNovelty),
                AppMessages.get(MessageKey.chatSuggestionResearchGap),
                AppMessages.get(MessageKey.chatSuggestionLimitation),
              ].map((suggestion) {
                return ActionChip(
                  label: Text(
                    suggestion,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor:
                      widget.primaryColor.withValues(alpha: 0.05),
                  side: BorderSide(
                    color: widget.primaryColor.withValues(alpha: 0.2),
                  ),
                  onPressed: () => _handleSuggestion(suggestion),
                );
              }).toList(),
            ),
          ),
        ),

        // Ô nhập tin nhắn
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatInputCtrl,
                  decoration: InputDecoration(
                    hintText: AppMessages.get(MessageKey.chatInputHint),
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
                  onPressed: widget.isChatLoading ? null : _handleSend,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
