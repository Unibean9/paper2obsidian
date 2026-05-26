import 'package:flutter/material.dart';

/// Tab 1 — Metadata form with 10 editable fields.
/// All TextEditingControllers are owned by the parent screen (_MainScreenState)
/// and passed by reference. This widget must NOT dispose them.
class MetadataTab extends StatelessWidget {
  const MetadataTab({
    super.key,
    required this.titleCtrl,
    required this.authorsCtrl,
    required this.venueCtrl,
    required this.yearCtrl,
    required this.doiCtrl,
    required this.keywordsCtrl,
    required this.datasetCtrl,
    required this.problemCtrl,
    required this.limitationCtrl,
    required this.summaryCtrl,
  });

  final TextEditingController titleCtrl;
  final TextEditingController authorsCtrl;
  final TextEditingController venueCtrl;
  final TextEditingController yearCtrl;
  final TextEditingController doiCtrl;
  final TextEditingController keywordsCtrl;
  final TextEditingController datasetCtrl;
  final TextEditingController problemCtrl;
  final TextEditingController limitationCtrl;
  final TextEditingController summaryCtrl;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildTextField('Title', titleCtrl, maxLines: 3),
          _buildTextField('Authors', authorsCtrl, maxLines: 3),
          _buildTextField('Venue', venueCtrl, maxLines: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTextField('Year', yearCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField('DOI', doiCtrl)),
            ],
          ),
          _buildTextField('Tags / Keywords', keywordsCtrl, maxLines: 2),
          _buildTextField('Dataset', datasetCtrl, maxLines: 2),
          _buildTextField('Problem Statement', problemCtrl, maxLines: 3),
          _buildTextField('Limitations', limitationCtrl, maxLines: 2),
          _buildTextField('Summary', summaryCtrl, maxLines: 6),
        ],
      ),
    );
  }
}

// HÀM XÂY DỰNG TEXTFIELD KIỂU MỚI: TÁCH BIỆT LABEL RA NGOÀI HOÀN TOÀN
Widget _buildTextField(
  String label,
  TextEditingController controller, {
  int maxLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        TextField(
          controller: controller,
          minLines: 1,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Enter $label...',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}
