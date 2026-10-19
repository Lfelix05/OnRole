/// Busca simples em memória: sem diferença entre maiúsculas e minúsculas nem
/// acentos ("forro" acha "Forró"), e todas as palavras digitadas precisam
/// aparecer em algum dos campos.
library;

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ç': 'c', 'ñ': 'n',
};

String normalizeForSearch(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

/// Verdadeiro se [query] está vazia ou se cada palavra dela aparece em
/// [fields] (campos nulos são ignorados).
bool matchesSearch(String query, Iterable<String?> fields) {
  final terms = normalizeForSearch(
    query,
  ).replaceAll('@', ' ').split(RegExp(r'\s+')).where((term) => term.isNotEmpty);
  if (terms.isEmpty) return true;
  final haystack = normalizeForSearch(fields.whereType<String>().join(' '));
  return terms.every(haystack.contains);
}
