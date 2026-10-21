import 'dart:math' as math;
import 'dart:typed_data';

/// Divide os bytes de uma foto/vídeo em pedaços de até [chunkSize]: cada
/// pedaço vira um documento do Firestore, que aceita no máximo 1 MiB.
List<Uint8List> splitIntoChunks(Uint8List bytes, int chunkSize) {
  assert(chunkSize > 0);
  return [
    for (var start = 0; start < bytes.length; start += chunkSize)
      Uint8List.sublistView(
        bytes,
        start,
        math.min(start + chunkSize, bytes.length),
      ),
  ];
}

/// Junta os pedaços, na ordem, de volta nos bytes originais.
Uint8List joinChunks(List<Uint8List> chunks) {
  final builder = BytesBuilder(copy: false);
  for (final chunk in chunks) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}
