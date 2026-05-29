import 'package:flutter/material.dart';

import '../constants/messages.dart';
import '../models/zotero_item.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({
    super.key,
    required this.vaultPath,
    required this.onOpenPaper,
    required this.loadLibrary,
    required this.primaryColor,
    this.isZoteroConfigured = false,
    this.activeCollectionKey,
    this.loadZoteroCollection,
    this.onImportZoteroItem,
    this.pendingZoteroItemKey,
  });

  final String vaultPath;
  final Future<void> Function(String mdPath) onOpenPaper;
  final Future<List<Map<String, String>>> Function() loadLibrary;
  final Color primaryColor;

  final bool isZoteroConfigured;
  final String? activeCollectionKey;

  /// Returns list of (item, isLocal) pairs from the Zotero collection.
  final Future<List<({ZoteroItem item, bool isLocal})>> Function(
      String collectionKey)? loadZoteroCollection;

  /// Called when user taps Import on a Zotero item.
  final Future<void> Function(ZoteroItem item)? onImportZoteroItem;

  /// Key of a Zotero item imported but not yet saved to Obsidian.
  /// Its Import button is disabled to prevent duplicate downloads.
  final String? pendingZoteroItemKey;

  @override
  State<LibraryTab> createState() => LibraryTabState();
}

class LibraryTabState extends State<LibraryTab> {
  // 0 = Local, 1 = Zotero
  int _activeSection = 0;

  // Local section state
  List<Map<String, String>> _localPapers = [];
  bool _isLoadingLocal = false;

  // Zotero section state
  List<({ZoteroItem item, bool isLocal})> _zoteroItems = [];
  bool _isLoadingZotero = false;
  String? _zoteroError;
  String _searchQuery = '';
  String? _importingKey;

  bool get _showZotero =>
      widget.isZoteroConfigured &&
      widget.activeCollectionKey != null &&
      widget.activeCollectionKey!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _refreshLocal();
    if (_showZotero) _refreshZotero();
  }

  @override
  void didUpdateWidget(covariant LibraryTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.vaultPath != oldWidget.vaultPath) {
      _refreshLocal();
    }

    final collectionChanged =
        widget.activeCollectionKey != oldWidget.activeCollectionKey ||
            widget.isZoteroConfigured != oldWidget.isZoteroConfigured;

    if (collectionChanged) {
      // If Zotero panel just became unavailable, snap back to Local
      if (!_showZotero && _activeSection == 1) {
        setState(() => _activeSection = 0);
      }
      if (_showZotero) _refreshZotero();
    }
  }

  // Called by MainScreen after save-to-obsidian to refresh both lists.
  void refresh() {
    _refreshLocal();
    if (_showZotero) _refreshZotero();
  }

  Future<void> _refreshLocal() async {
    if (!mounted) return;
    setState(() => _isLoadingLocal = true);
    try {
      final papers = await widget.loadLibrary();
      if (mounted) setState(() => _localPapers = papers);
    } finally {
      if (mounted) setState(() => _isLoadingLocal = false);
    }
  }

  Future<void> _refreshZotero() async {
    if (!mounted) return;
    final collectionKey = widget.activeCollectionKey;
    if (collectionKey == null || widget.loadZoteroCollection == null) return;
    setState(() {
      _isLoadingZotero = true;
      _zoteroError = null;
    });
    try {
      final items = await widget.loadZoteroCollection!(collectionKey);
      if (mounted) setState(() => _zoteroItems = items);
    } catch (e) {
      if (mounted) setState(() => _zoteroError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingZotero = false);
    }
  }

  Future<void> _importItem(ZoteroItem item) async {
    if (widget.onImportZoteroItem == null) return;
    setState(() => _importingKey = item.key);
    try {
      await widget.onImportZoteroItem!(item);
      // Do NOT mark isLocal here — paper is only local after "Save to Obsidian".
      // MainScreen tracks pending state via pendingZoteroItemKey.
    } catch (_) {
      // Errors are surfaced by MainScreen's progress log.
    } finally {
      if (mounted) setState(() => _importingKey = null);
    }
  }

  // =========================================================================
  // Build
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showZotero) _buildToggleHeader(),
        Expanded(
          child: _activeSection == 1 ? _buildZoteroSection() : _buildLocalSection(),
        ),
      ],
    );
  }

  Widget _buildToggleHeader() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          _SectionTab(
            label: 'Local (${_localPapers.length})',
            icon: Icons.folder_outlined,
            selected: _activeSection == 0,
            primaryColor: widget.primaryColor,
            onTap: () => setState(() => _activeSection = 0),
          ),
          const SizedBox(width: 4),
          _SectionTab(
            label: _isLoadingZotero
                ? 'Zotero…'
                : 'Zotero (${_zoteroItems.length})',
            icon: Icons.cloud_outlined,
            selected: _activeSection == 1,
            primaryColor: widget.primaryColor,
            onTap: () => setState(() => _activeSection = 1),
          ),
        ],
      ),
    );
  }

  // ─── Local section ─────────────────────────────────────────────────────────

  Widget _buildLocalSection() {
    if (_isLoadingLocal) {
      return Center(
          child: CircularProgressIndicator(color: widget.primaryColor));
    }
    if (_localPapers.isEmpty) {
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
                AppMessages.labelSavedNotesCount(_localPapers.length),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: AppMessages.get(MessageKey.libraryRefreshTooltip),
                onPressed: _refreshLocal,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _localPapers.length,
            itemBuilder: (context, index) {
              final paper = _localPapers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      widget.primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.description,
                      size: 16, color: widget.primaryColor),
                ),
                title: Text(
                  paper['title']!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                subtitle: Text('Year: ${paper['year']}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 12, color: Colors.grey.shade400),
                onTap: () => widget.onOpenPaper(
                    paper['dedup_key'] ?? paper['path'] ?? ''),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Zotero section ────────────────────────────────────────────────────────

  Widget _buildZoteroSection() {
    if (_isLoadingZotero) {
      return Center(
          child: CircularProgressIndicator(color: widget.primaryColor));
    }

    if (_zoteroError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 40, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text('Failed to load Zotero collection',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700)),
              const SizedBox(height: 6),
              Text(_zoteroError!,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _refreshZotero,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_zoteroItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_queue, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No papers in this Zotero collection.',
                style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _refreshZotero,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    final filtered = _searchQuery.isEmpty
        ? _zoteroItems
        : _zoteroItems.where((r) {
            final q = _searchQuery.toLowerCase();
            return r.item.title.toLowerCase().contains(q) ||
                r.item.authors.toLowerCase().contains(q);
          }).toList();

    final notImported = _zoteroItems.where((r) => !r.isLocal).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search papers…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh from Zotero',
                onPressed: _refreshZotero,
              ),
            ],
          ),
        ),
        if (notImported > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(
              children: [
                Text('$notImported not imported yet',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _importingKey != null
                      ? null
                      : () async {
                          for (final r
                              in List.of(_zoteroItems.where((r) => !r.isLocal))) {
                            if (!mounted) return;
                            await _importItem(r.item);
                          }
                        },
                  icon: const Icon(Icons.download_for_offline_outlined,
                      size: 14),
                  label: const Text('Import All',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) => _buildZoteroItem(filtered[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildZoteroItem(({ZoteroItem item, bool isLocal}) record) {
    final item = record.item;
    final isLocal = record.isLocal;
    final isImporting = _importingKey == item.key;
    final isPending = widget.pendingZoteroItemKey == item.key;

    Widget trailing;
    if (isLocal) {
      trailing = Chip(
        label: const Text('Saved', style: TextStyle(fontSize: 10)),
        backgroundColor: Colors.green.shade50,
        side: BorderSide(color: Colors.green.shade200),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      );
    } else if (isImporting) {
      trailing = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: widget.primaryColor),
      );
    } else if (isPending) {
      trailing = Chip(
        label: Text('Reviewing…',
            style: TextStyle(fontSize: 10, color: Colors.orange.shade800)),
        backgroundColor: Colors.orange.shade50,
        side: BorderSide(color: Colors.orange.shade200),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      );
    } else {
      trailing = Tooltip(
        message: 'Download & extract this paper',
        child: IconButton(
          icon:
              Icon(Icons.download_outlined, size: 18, color: widget.primaryColor),
          onPressed: () => _importItem(item),
        ),
      );
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isLocal
            ? Colors.green.shade50
            : isPending
                ? Colors.orange.shade50
                : widget.primaryColor.withValues(alpha: 0.08),
        child: Icon(
          isLocal
              ? Icons.check
              : isPending
                  ? Icons.edit_outlined
                  : Icons.cloud_outlined,
          size: 16,
          color: isLocal
              ? Colors.green.shade700
              : isPending
                  ? Colors.orange.shade700
                  : widget.primaryColor,
        ),
      ),
      title: Text(item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Text(
        [item.authors, if (item.year != null) item.year!]
            .where((s) => s.isNotEmpty)
            .join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      trailing: trailing,
    );
  }
}

// ─── Toggle tab button ────────────────────────────────────────────────────────

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? primaryColor : Colors.grey.shade500),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? primaryColor : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
