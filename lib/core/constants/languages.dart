class GeoHarvestLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String family;
  final int speakerCount;
  final bool supportedByGhanaNLP;
  final bool supportedByWhisper;
  final bool hasLocalTTS;
  final bool hasLocalASR;

  const GeoHarvestLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.family,
    required this.speakerCount,
    this.supportedByGhanaNLP = false,
    this.supportedByWhisper = false,
    this.hasLocalTTS = false,
    this.hasLocalASR = false,
  });
}

const allGhanaianLanguages = [
  GeoHarvestLanguage(
    code: 'tw',
    name: 'Twi (Asante/Akuapem)',
    nativeName: 'Twi',
    family: 'Akan',
    speakerCount: 7500000,
    supportedByGhanaNLP: true,
    supportedByWhisper: true,
  ),
  GeoHarvestLanguage(
    code: 'fat',
    name: 'Fante',
    nativeName: 'Fante',
    family: 'Akan',
    speakerCount: 2000000,
    supportedByWhisper: true,
  ),
  GeoHarvestLanguage(
    code: 'en-GH',
    name: 'Ghanaian English',
    nativeName: 'Ghanaian English',
    family: 'English (Creole)',
    speakerCount: 25000000,
    supportedByGhanaNLP: true,
    supportedByWhisper: true,
  ),
  GeoHarvestLanguage(
    code: 'gaa',
    name: 'Ga',
    nativeName: 'Gã',
    family: 'Kwa',
    speakerCount: 1000000,
    supportedByGhanaNLP: true,
    supportedByWhisper: true,
  ),
  GeoHarvestLanguage(
    code: 'dag',
    name: 'Dagbani',
    nativeName: 'Dagbani',
    family: 'Mole-Dagbani',
    speakerCount: 800000,
    supportedByGhanaNLP: true,
    supportedByWhisper: true,
  ),
  GeoHarvestLanguage(
    code: 'ee',
    name: 'Ewe',
    nativeName: 'Eʋe',
    family: 'Gbe',
    speakerCount: 200000,
    supportedByGhanaNLP: true,
    supportedByWhisper: true,
  ),
  GeoHarvestLanguage(
    code: 'gur',
    name: 'Gurene (Frafra)',
    nativeName: 'Frafra',
    family: 'Gur',
    speakerCount: 500000,
    supportedByWhisper: true,
  ),
  GeoHarvestLanguage(
    code: 'dang',
    name: 'Dangme (Ada)',
    nativeName: 'Dangme',
    family: 'Kwa',
    speakerCount: 300000,
    supportedByWhisper: true,
  ),
  GeoHarvestLanguage(
    code: 'bon',
    name: 'Bono',
    nativeName: 'Bono',
    family: 'Akan',
    speakerCount: 1000000,
    supportedByWhisper: true,
  ),
  GeoHarvestLanguage(
    code: 'nzm',
    name: 'Nzema',
    nativeName: 'Nzema',
    family: 'Kwa',
    speakerCount: 200000,
    supportedByWhisper: true,
  ),
  GeoHarvestLanguage(
    code: 'yo',
    name: 'Yoruba',
    nativeName: 'Yorùbá',
    family: 'Niger-Congo',
    speakerCount: 500000,
    supportedByGhanaNLP: true,
    supportedByWhisper: true,
  ),
  GeoHarvestLanguage(
    code: 'ki',
    name: 'Kikuyu',
    nativeName: 'Gĩkũyũ',
    family: 'Bantu',
    speakerCount: 500000,
    supportedByGhanaNLP: true,
    supportedByWhisper: true,
  ),
];

GeoHarvestLanguage? getLanguageByCode(String code) {
  try {
    return allGhanaianLanguages.firstWhere((l) => l.code == code);
  } on StateError {
    return null;
  }
}

String getLanguageDisplayName(String code) {
  final lang = getLanguageByCode(code);
  return lang?.name ?? code.toUpperCase();
}

const String defaultLanguage = 'tw';
