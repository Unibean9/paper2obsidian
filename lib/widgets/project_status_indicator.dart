import 'package:flutter/material.dart';

class ProjectStatusIndicator extends StatelessWidget {
  const ProjectStatusIndicator({
    super.key,
    required this.hasCollectionKey,
    required this.isZoteroConfigured,
  });

  final bool hasCollectionKey;
  final bool isZoteroConfigured;

  @override
  Widget build(BuildContext context) {
    if (!isZoteroConfigured) {
      return Tooltip(
        message: 'Zotero not configured — add API key in Settings',
        child: Chip(
          avatar: const Icon(Icons.link_off, size: 14, color: Colors.grey),
          label: const Text('No Zotero', style: TextStyle(fontSize: 11)),
          backgroundColor: Colors.grey.shade100,
          side: BorderSide(color: Colors.grey.shade300),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    if (!hasCollectionKey) {
      return Tooltip(
        message: 'No Zotero collection linked — edit project to add one',
        child: Chip(
          avatar: Icon(Icons.link, size: 14, color: Colors.orange.shade700),
          label: Text('No collection',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
          backgroundColor: Colors.orange.shade50,
          side: BorderSide(color: Colors.orange.shade200),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    return Tooltip(
      message: 'Zotero collection linked — Import/Export ready',
      child: Chip(
        avatar: Icon(Icons.link, size: 14, color: Colors.green.shade700),
        label: Text('Zotero linked',
            style: TextStyle(fontSize: 11, color: Colors.green.shade800)),
        backgroundColor: Colors.green.shade50,
        side: BorderSide(color: Colors.green.shade200),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
