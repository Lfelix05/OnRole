import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/data/repositories.dart';
import 'package:on_role/models/media.dart';
import 'package:on_role/providers/media_loader.dart';

/// Repositório que conta os downloads e só entrega quando o teste mandar.
class _SlowRepository implements MediaRepository {
  int loads = 0;
  final pending = Completer<Uint8List>();

  @override
  Future<Uint8List> load(MediaRef media) {
    loads++;
    return pending.future;
  }

  @override
  Future<MediaRef> upload({
    required String ownerId,
    required MediaDraft draft,
    void Function(double progress)? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(MediaRef media) => throw UnimplementedError();
}

MediaRef _ref(String id) => MediaRef(
  id: id,
  kind: MediaKind.image,
  mimeType: 'image/jpeg',
  chunkCount: 1,
  aspectRatio: 1,
);

void main() {
  test(
    'pedidos simultâneos da mesma mídia baixam uma vez e terminam',
    () async {
      final repository = _SlowRepository();
      final loader = MediaLoader(repository);

      final first = loader.load(_ref('a'));
      final second = loader.load(_ref('a'));
      repository.pending.complete(Uint8List.fromList([1, 2, 3]));

      // Antes da correção, o Future esperava por ele mesmo e nunca terminava.
      final results = await Future.wait([
        first,
        second,
      ]).timeout(const Duration(seconds: 2));
      expect(results, [
        [1, 2, 3],
        [1, 2, 3],
      ]);
      expect(repository.loads, 1);
      expect(loader.cached('a'), [1, 2, 3]);
    },
  );

  test('acima do limite, sai da memória a mídia vista há mais tempo', () {
    final loader = MediaLoader(_SlowRepository(), maxCacheBytes: 10);

    loader.remember('velha', Uint8List(6));
    loader.remember('nova', Uint8List(6));

    expect(loader.cached('velha'), isNull);
    expect(loader.cached('nova'), isNotNull);
  });
}
