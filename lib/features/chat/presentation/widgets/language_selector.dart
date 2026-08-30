import 'package:flutter/material.dart';

class LanguageSelector extends StatelessWidget {
  final String selectedLanguage;
  final List<String> availableLanguages;
  final Function(String) onLanguageSelected;
  final Map<String, String> languageNames;

  const LanguageSelector({
    Key? key,
    required this.selectedLanguage,
    required this.availableLanguages,
    required this.onLanguageSelected,
    required this.languageNames,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: DropdownButton<String>(
        value: selectedLanguage,
        onChanged: (value) {
          if (value != null) {
            onLanguageSelected(value);
          }
        },
        underline: const SizedBox(),
        icon: const Icon(Icons.language, color: Colors.deepPurple, size: 20),
        dropdownColor: const Color(0xFF0F0F0F),
        items: availableLanguages
            .map((lang) => DropdownMenuItem(
                  value: lang,
                  child: Text(
                    languageNames[lang] ?? lang,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
