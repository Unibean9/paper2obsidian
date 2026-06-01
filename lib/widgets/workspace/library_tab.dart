import 'package:flutter/material.dart';

import '../../constants/messages.dart';
import '../../models/zotero_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../common/app_empty_state.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({
    super.key,
    required this.vaultPath,
    required this.onOpenPaper,
    required this.loadLibrary,
    this.isZoteroConfigured = false,
    this.activeCollectionKey,
    this.loadZoteroCollection,
    this.onImportZoteroItem,
    this.pendingZoteroItemKey,
  });

  final String vaultPath;
  final Future<void> Function(String mdPath) onOpenPaper;
  final Future<List<Map<String, String>>> Function() loadLibrary;

  final bool isZoteroConfigured;
  final String? activeCollectionKey;
  final Future<List<({ZoteroItem item, bool isLocal})>> Function(
    String collectionKey,
  )?
  loadZoteroCollection;
  final Future<void> Function(ZoteroItem item)? onImportZoteroItem;
  final String? pendingZoteroItemKey;

  @override
  State<LibraryTab> createState() => LibraryTabState();
}

class LibraryTabState extends State<LibraryTab> {
  int _activeSection = 0;

  List<Map<String, String>> _localPapers = [];
  bool _isLoadingLocal = false;

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
      if (!_showZotero && _activeSection == 1) {
        setState(() => _activeSection = 0);
      }
      if (_showZotero) _refreshZotero();
    }
  }

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
    } finally {
      if (mounted) setState(() => _importingKey = null);
    }
  }

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
      color: AppColors.surfaceLight,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          _SectionTab(
            label: 'Local (${_localPapers.length})',
            icon: Icons.folder_outlined,
            selected: _activeSection == 0,
            onTap: () => setState(() => _activeSection = 0),
          ),
          const SizedBox(width: AppSpacing.xs),
          _SectionTab(
            label: _isLoadingZotero ? 'Zotero…' : 'Zotero (${_zoteroItems.length})',
            icon: Icons.cloud_outlined,
            selected: _activeSection == 1,
            onTap: () => setState(() => _activeSection = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalSection() {
    final theme = Theme.of(context);

    if (_isLoadingLocal) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_localPapers.isEmpty) {
      return AppEmptyState(
        icon: Icons.folder_open,
        title: AppMessages.get(MessageKey.libraryEmpty),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Text(
                AppMessages.labelSavedNotesCount(_localPapers.length),
                style: theme.textTheme.titleLarge,
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
                leading: const CircleAvatar(
                  backgroundColor: AppColors.surfaceNeutral,
                  child: Icon(Icons.description, size: 16, color: AppColors.primary),
                ),
                title: Text(
                  paper['title']!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('Year: ${paper['year']}'),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: AppColors.textMuted,
                ),
                onTap: () => widget.onOpenPaper(
                  paper['dedup_key'] ?? paper['path'] ?? '',
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildZoteroSection() {
    final theme = Theme.of(context);

    if (_isLoadingZotero) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_zoteroError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 40, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Failed to load Zotero collection',
                style: theme.textTheme.titleLarge?.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _zoteroError!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
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
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppEmptyState(
            icon: Icons.cloud_queue,
            title: 'No papers in this Zotero collection.',
          ),
          OutlinedButton.icon(
            onPressed: _refreshZotero,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      );
    }

    final filtered = _searchQuery.isEmpty
        ? _zoteroItems
        : _zoteroItems.where((record) {
            final query = _searchQuery.toLowerCase();
            return record.item.title.toLowerCase().contains(query) ||
                record.item.authors.toLowerCase().contains(query);
          }).toList();

    final notImported = _zoteroItems.where((record) => !record.isLocal).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search papers…',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                  ),
                  style: theme.textTheme.labelLarge,
                  onChanged: (value) => setState(() => _searchQuery = value),
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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                Text(
                  '$notImported not imported yet',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _importingKey != null
                      ? null
                      : () async {
                          for (final record
                              in List.of(_zoteroItems.where((item) => !item.isLocal))) {
                            if (!mounted) return;
                            await _importItem(record.item);
                          }
                        },
                  icon: const Icon(Icons.download_for_offline_outlined, size: 14),
                  label: const Text('Import All'),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, index) => _buildZoteroItem(filtered[index]),
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
      trailing = const Chip(
        label: Text('Saved'),
        backgroundColor: AppColors.successSurface,
        side: BorderSide(color: AppColors.successSurface),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      );
    } else if (isImporting) {
      trailing = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
      );
    } else if (isPending) {
      trailing = const Chip(
        label: Text('Reviewing…'),
        backgroundColor: AppColors.warningSurface,
        side: BorderSide(color: AppColors.warningSurface),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      );
    } else {
      trailing = Tooltip(
        message: 'Download & extract this paper',
        child: IconButton(
          icon: const Icon(Icons.download_outlined, size: 18, color: AppColors.primary),
          onPressed: () => _importItem(item),
        ),
      );
    }

    final iconBackground = isLocal
        ? AppColors.successSurface
        : isPending
        ? AppColors.warningSurface
        : AppColors.surfaceNeutral;
    final iconColor = isLocal
        ? AppColors.success
        : isPending
        ? AppColors.warning
        : AppColors.primary;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconBackground,
        child: Icon(
          isLocal
              ? Icons.check
              : isPending
              ? Icons.edit_outlined
              : Icons.cloud_outlined,
          size: 16,
          color: iconColor,
        ),
      ),
      title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [item.authors, if (item.year != null) item.year!]
            .where((value) => value.isNotEmpty)
            .join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing,
    );
  }
}

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.xs + 1),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
