import '../../../../core/constants/languages.dart';

class LanguageDetector {
  static final Map<String, RegExp> _charPatterns = {
    'tw': RegExp(r'[ƆɔɛƐ]'),
    'gaa': RegExp(r'[ƆɔɛƐ]'),
    'ee': RegExp(r'[ɛƐ]'),
    'dag': RegExp(r'[ŋƴ]'),
    'gur': RegExp(r'[ŋƴ]'),
    'yo': RegExp(r'[ẹọṣgb]'),
    'nzm': RegExp(r'[ɛƐ]'),
  };

  static final Map<String, List<String>> _commonWords = {
    'tw': ['me', 'wo', 'ɔ', 'yɛ', 'na', 'sɛ', 'mpɛ', 'hwɛ', 'ka', 'ba', 'kɔ', 'wɔ', 'nɛ', 'sika', 'aduonu', 'mmienu'],
    'gaa': ['me', 'mi', 'ɔ', 'nyɛ', 'na', 'kɛ', 'mi', 'hwɛ', 'kasa', 'ba', 'kɔ', 'le', 'nɛ', 'sikɛ', 'enɛ'],
    'dag': ['m', 'a', 'o', 'nyɛ', 'la', 'bee', 'm', 'nɔ', 'zah', 'ka', 'kɔ', 'din', 'nyɛ', 'sikɛ', 'awiyɛ'],
  };

  static String detect(String text, String? deviceLocale) {
    if (text.isEmpty || text.length < 2) {
      return deviceLocale ?? defaultLanguage;
    }

    final lower = text.toLowerCase();

    final charScores = <String, int>{};
    for (final entry in _charPatterns.entries) {
      final matches = entry.value.allMatches(text).length;
      charScores[entry.key] = matches;
    }

    final words = lower.split(RegExp(r'\s+'));
    final wordScores = <String, int>{};
    for (final entry in _commonWords.entries) {
      int score = 0;
      for (final word in entry.value) {
        if (words.contains(word)) score++;
      }
      wordScores[entry.key] = score;
    }

    final englishWords = ['the', 'is', 'and', 'to', 'of', 'in', 'that', 'for', 'it', 'with', 'i', 'you', 'have', 'can', 'will', 'not', 'but', 'what', 'all', 'we'];
    final englishScore = words.where((w) => englishWords.contains(w)).length;

    final combinedScores = <String, double>{};
    for (final lang in charScores.keys) {
      final charScore = charScores[lang] ?? 0;
      final wordScore = wordScores[lang] ?? 0;
      combinedScores[lang] = (charScore * 3.0) + (wordScore * 2.0);
    }

    String? bestLang;
    double bestScore = 0;
    for (final entry in combinedScores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestLang = entry.key;
      }
    }

    if (bestScore >= 2.0 && bestLang != null) {
      return bestLang;
    }

    if (englishScore >= 2) {
      return 'en-GH';
    }

    if (deviceLocale != null && deviceLocale != 'en') {
      return deviceLocale;
    }

    return defaultLanguage;
  }

  static GeoHarvestLanguage? getByCode(String code) {
    try {
      return allGhanaianLanguages.firstWhere((l) => l.code == code);
    } on StateError {
      return null;
    }
  }

  static String getDisplayName(String code) {
    final lang = getByCode(code);
    return lang?.name ?? code.toUpperCase();
  }
}
