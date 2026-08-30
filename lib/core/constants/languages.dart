/// Supported Ghanaian languages with metadata
class GhanaianLanguage {
  final String code; // e.g., 'tw', 'ee', 'gaa'
  final String name; // e.g., 'Twi (Akan)'
  final String nativeName; // e.g., 'Twi'
  final String flag; // Emoji flag
  final int speakers; // Number of speakers
  final bool isSupported; // Whether ASR/TTS is supported

  const GhanaianLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.speakers,
    required this.isSupported,
  });
}

const List<GhanaianLanguage> allGhanaianLanguages = [
  GhanaianLanguage(
    code: 'tw',
    name: 'Twi (Akan)',
    nativeName: 'Twi',
    flag: '🇬🇭',
    speakers: 8000000,
    isSupported: true,
  ),
  GhanaianLanguage(
    code: 'ee',
    name: 'Ewe',
    nativeName: 'Eʋe',
    flag: '🇬🇭',
    speakers: 3000000,
    isSupported: true,
  ),
  GhanaianLanguage(
    code: 'gaa',
    name: 'Ga',
    nativeName: 'Gã',
    flag: '🇬🇭',
    speakers: 2000000,
    isSupported: true,
  ),
  GhanaianLanguage(
    code: 'dag',
    name: 'Dagbani',
    nativeName: 'Dagbani',
    flag: '🇬🇭',
    speakers: 600000,
    isSupported: true,
  ),
  GhanaianLanguage(
    code: 'fat',
    name: 'Fante',
    nativeName: 'Fante',
    flag: '🇬🇭',
    speakers: 1500000,
    isSupported: true,
  ),
  GhanaianLanguage(
    code: 'ha',
    name: 'Hausa',
    nativeName: 'Hausa',
    flag: '🇬🇭',
    speakers: 700000,
    isSupported: true,
  ),
  GhanaianLanguage(
    code: 'yo',
    name: 'Yoruba',
    nativeName: 'Yorùbá',
    flag: '🇬🇭',
    speakers: 500000,
    isSupported: true,
  ),
  GhanaianLanguage(
    code: 'en-GH',
    name: 'English (Ghana)',
    nativeName: 'English',
    flag: '🇬🇭',
    speakers: 9000000,
    isSupported: true,
  ),
];

const String defaultLanguage = 'tw';

String getLanguageDisplayName(String? code) {
  if (code == null || code.isEmpty) return 'Select Language';
  try {
    return allGhanaianLanguages
        .firstWhere((lang) => lang.code == code)
        .name;
  } catch (_) {
    return code;
  }
}

String getLanguageNativeName(String? code) {
  if (code == null || code.isEmpty) return '';
  try {
    return allGhanaianLanguages
        .firstWhere((lang) => lang.code == code)
        .nativeName;
  } catch (_) {
    return code;
  }
}

bool isLanguageSupported(String? code) {
  if (code == null || code.isEmpty) return false;
  try {
    return allGhanaianLanguages
        .firstWhere((lang) => lang.code == code)
        .isSupported;
  } catch (_) {
    return false;
  }
}
