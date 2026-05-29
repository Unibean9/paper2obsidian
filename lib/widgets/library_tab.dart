import 'package:flutter/material.dart';

import '../constants/messages.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({
    super.key,
    required this.vaultPath,
    required this.onOpenPaper,
    required this.loadLibrary,
    required this.primaryColor,
  });

  final String vaultPath;

  final Future<void> Function(String mdPath) onOpenPaper;

  final Future<List<Map<String, String>>> Function() loadLibrary;

  final Color primaryColor;

  @override
  State<LibraryTab> createState() => LibraryTabState();
}

class LibraryTabState extends State<LibraryTab> {
  List<Map<String, String>> _papers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant LibraryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload when vaultPath changes.
    if (widget.vaultPath != oldWidget.vaultPath) {
      _refresh();
    }
  }

  void refresh() => _refresh();

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final List<Map<String, String>> papers = await widget.loadLibrary();
      if (mounted) setState(() => _papers = papers);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: widget.primaryColor),
      );
    }

    if (_papers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              AppMessages.get(MessageKey.libraryEmpty),
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Text(
                AppMessages.labelSavedNotesCount(_papers.length),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: AppMessages.get(MessageKey.libraryRefreshTooltip),
                onPressed: _refresh,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _papers.length,
            itemBuilder: (context, index) {
              final Map<String, String> paper = _papers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: widget.primaryColor.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.description,
                    size: 16,
                    color: widget.primaryColor,
                  ),
                ),
                title: Text(
                  paper['title']!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'Year: ${paper['year']}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
                onTap: () => widget.onOpenPaper(paper['path']!),
              );
            },
          ),
        ),
      ],
    );
  }
}
