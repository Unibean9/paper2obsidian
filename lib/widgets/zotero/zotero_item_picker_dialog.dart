import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/zotero_item.dart';

class ZoteroItemPickerDialog extends StatefulWidget {
  const ZoteroItemPickerDialog({
    super.key,
    required this.items,
    required this.collectionName,
  });

  final List<ZoteroItem> items;
  final String collectionName;

  @override
  State<ZoteroItemPickerDialog> createState() =>
      _ZoteroItemPickerDialogState();
}

class _ZoteroItemPickerDialogState extends State<ZoteroItemPickerDialog> {
  String _filter = '';
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<ZoteroItem> get _filtered {
    if (_filter.isEmpty) return widget.items;
    final q = _filter.toLowerCase();
    return widget.items
        .where((i) =>
            i.title.toLowerCase().contains(q) ||
            i.authors.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.pop(context);
        },
      },
      child: AlertDialog(
        title: const Text(
          'Import from Zotero',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 520,
          height: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Collection: ${widget.collectionName}  •  ${widget.items.length} items',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by title or author…',
                  prefixIcon: Icon(Icons.search, size: 18),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(child: Text('No items match.'))
                    : Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: _scrollController,
                          itemCount: _filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final item = _filtered[i];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.picture_as_pdf_outlined,
                                  size: 20),
                              title: Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium,
                              ),
                              subtitle: Text(
                                '${item.authors}'
                                '${item.year != null ? "  •  ${item.year}" : ""}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade600),
                              ),
                              onTap: () => Navigator.pop(context, item),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
