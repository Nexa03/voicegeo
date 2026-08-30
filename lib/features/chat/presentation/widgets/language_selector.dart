import 'package:flutter/material.dart';
import '../../../../core/constants/languages.dart';

class LanguageSelector extends StatelessWidget {
  final String selectedLanguage;
  final void Function(String) onLanguageSelected;

  const LanguageSelector({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final currentLang = getLanguageByCode(selectedLanguage);
    final displayName = currentLang?.name ?? selectedLanguage.toUpperCase();

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 14, color: Colors.deepPurple),
            const SizedBox(width: 6),
            Text(
              displayName,
              style: TextStyle(color: Colors.grey[300], fontSize: 12),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _LanguagePickerSheet(
        selectedLanguage: selectedLanguage,
        onSelected: (code) {
          Navigator.pop(context);
          onLanguageSelected(code);
        },
      ),
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  final String selectedLanguage;
  final void Function(String) onSelected;

  const _LanguagePickerSheet({
    required this.selectedLanguage,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Select Language',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allGhanaianLanguages.length,
            itemBuilder: (context, index) {
              final lang = allGhanaianLanguages[index];
              final isSelected = lang.code == selectedLanguage;
              return ListTile(
                title: Text(
                  lang.name,
                  style: TextStyle(
                    color: isSelected ? Colors.deepPurple : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  lang.nativeName,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.deepPurple)
                    : null,
                onTap: () => onSelected(lang.code),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
