import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/data/repositories.dart';
import 'package:on_role/services/media_chunks.dart';

void main() {
  Uint8List bytesOf(int length) =>
      Uint8List.fromList(List.generate(length, (i) => (i * 7) % 256));

  test('divide em pedaços do tamanho pedido, com o resto no último', () {
    final chunks = splitIntoChunks(bytesOf(25), 10);

    expect(chunks.map((chunk) => chunk.length), [10, 10, 5]);
  });

  test('juntar os pedaços devolve os bytes originais', () {
    final bytes = bytesOf(mediaChunkSize * 2 + 123);

    expect(joinChunks(splitIntoChunks(bytes, mediaChunkSize)), bytes);
  });

  test('arquivo que cabe num documento vira um pedaço só', () {
    expect(
      splitIntoChunks(bytesOf(mediaChunkSize), mediaChunkSize),
      hasLength(1),
    );
  });

  test('o maior arquivo aceito cabe no limite de pedaços das regras', () {
    final chunks = splitIntoChunks(Uint8List(maxMediaBytes), mediaChunkSize);

    // firestore.rules aceita até 12 pedaços por mídia.
    expect(chunks.length, lessThanOrEqualTo(12));
  });
}
