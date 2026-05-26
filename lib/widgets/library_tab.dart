import 'package:flutter/material.dart';

/// Tab 4 — Vault Library: shows all saved paper notes from the Obsidian vault.
/// Owns its loading state and paper list (Bucket C).
/// Exposes a public [refresh] method so the parent screen can trigger a reload
/// via GlobalKey after "Save to Obsidian" completes.
class LibraryTab extends StatefulWidget {
  const LibraryTab({
    super.key,
    required this.vaultPath,
    required this.onOpenPaper,
    required this.loadLibrary,
    required this.primaryColor,
  });

  final String vaultPath;

  /// Called when the user taps a paper in the list. Receives the .md file path.
  final Future<void> Function(String mdPath) onOpenPaper;

  /// Async function that loads the list of papers. Returns [] if vaultPath is empty.
  final Future<List<Map<String, String>>> Function() loadLibrary;

  final Color primaryColor;

  @override
  State<LibraryTab> createState() => LibraryTabState();
}

/// Public state class — exposed so the parent screen can call [refresh]
/// via a [GlobalKey<LibraryTabState>] after "Save to Obsidian" completes.
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
    // Tải lại khi vault path thay đổi
    if (widget.vaultPath != oldWidget.vaultPath) {
      _refresh();
    }
  }

  /// Called externally via GlobalKey after a successful save to Obsidian.
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
              'Library is empty.',
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
                'Saved Notes (${_papers.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Làm mới thư viện',
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
                // Kích hoạt vòng lặp đóng đọc lại file
                onTap: () => widget.onOpenPaper(paper['path']!),
              );
            },
          ),
        ),
      ],
    );
  }
}
