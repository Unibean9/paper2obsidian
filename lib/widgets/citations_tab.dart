import 'package:flutter/material.dart';

class CitationsTab extends StatelessWidget {
  const CitationsTab({
    super.key,
    required this.citations,
    required this.primaryColor,
  });

  final List<String> citations;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    if (citations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.format_quote, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No citations extracted yet.',
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
          child: Text(
            'Extracted Citations (${citations.length})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: citations.length,
            itemBuilder: (context, index) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  citations[index],
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
