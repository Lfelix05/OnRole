import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/services/text_search.dart';

void main() {
  test('ignora maiúsculas e acentos', () {
    expect(normalizeForSearch('Forró na Praça'), 'forro na praca');
    expect(matchesSearch('FORRO', ['Forró']), isTrue);
    expect(matchesSearch('área verde', ['Area Verde']), isTrue);
  });

  test('todas as palavras precisam aparecer, em qualquer campo', () {
    final fields = ['Marina Alves', 'Samba e pagode', null];
    expect(matchesSearch('marina samba', fields), isTrue);
    expect(matchesSearch('marina rock', fields), isFalse);
  });

  test('busca vazia ou só com @ mostra tudo', () {
    expect(matchesSearch('', ['qualquer']), isTrue);
    expect(matchesSearch('  @ ', ['qualquer']), isTrue);
    expect(matchesSearch('@marinaalves', ['@marinaalves']), isTrue);
  });
}
