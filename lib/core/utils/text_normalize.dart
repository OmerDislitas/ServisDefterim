/// Turkce arama normalizasyonu (PLAN 6.4).
///
/// SQLite `lower()` Turkce karakterleri dogru islemedigi icin arama yapilan
/// metinler kayit sirasinda bu fonksiyonla normalize edilip `searchText`
/// kolonunda saklanir. Arama terimi de ayni fonksiyondan gecirilir.
library;

const _fold = {
  'ç': 'c',
  'ğ': 'g',
  'ı': 'i',
  'ö': 'o',
  'ş': 's',
  'ü': 'u',
  'â': 'a',
  'î': 'i',
  'û': 'u',
};

final _spaces = RegExp(r'\s+');

/// Turkce kurallarina gore kucuk harf: I -> ı, İ -> i.
String turkishLower(String input) =>
    input.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().replaceAll('̇', '');

/// Kucuk harf + aksan kaldirma + bosluklari tekillestirme.
/// "Şükrü  ÖZTÜRK" -> "sukru ozturk"
String normalizeForSearch(String? input) {
  if (input == null || input.isEmpty) return '';
  final lower = turkishLower(input);
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(_fold[ch] ?? ch);
  }
  return buf.toString().replaceAll(_spaces, ' ').trim();
}

/// Birden fazla alani normalize edip bosluklarla birlestirir.
String buildSearchText(Iterable<String?> parts) =>
    parts.map(normalizeForSearch).where((p) => p.isNotEmpty).join(' ');

/// LIKE desenindeki ozel karakterleri kacirir (ESCAPE '\' ile kullanilir).
String escapeLike(String input) =>
    input.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
