import 'dart:typed_data';

import '../data/repositories.dart';
import '../models/media.dart';

/// Baixa os bytes das fotos e vídeos e guarda os mais recentes em memória,
/// para o feed não baixar tudo de novo a cada rolagem.
class MediaLoader {
  MediaLoader(this._repository, {this.maxCacheBytes = 80 * 1024 * 1024});

  final MediaRepository _repository;

  /// Acima disso, as mídias vistas há mais tempo saem da memória.
  final int maxCacheBytes;

  // Mapas em Dart mantêm a ordem de inserção: reinserindo a cada uso, a
  // primeira chave é sempre a usada há mais tempo.
  final _cache = <String, Uint8List>{};
  final _inFlight = <String, Future<Uint8List>>{};
  int _cachedBytes = 0;

  /// Bytes já em memória (sem baixar).
  Uint8List? cached(String mediaId) {
    final bytes = _cache.remove(mediaId);
    if (bytes != null) _cache[mediaId] = bytes;
    return bytes;
  }

  Future<Uint8List> load(MediaRef media) {
    final hit = cached(media.id);
    if (hit != null) return Future.value(hit);
    // Vários widgets pedindo a mesma mídia ao mesmo tempo dividem o download.
    return _inFlight[media.id] ??= _repository
        .load(media)
        .then((bytes) {
          remember(media.id, bytes);
          return bytes;
        })
        // Corpo em bloco de propósito: com "=>", o callback devolveria o
        // próprio Future removido do mapa e o whenComplete esperaria por ele
        // mesmo para sempre.
        .whenComplete(() {
          _inFlight.remove(media.id);
        });
  }

  /// Guarda bytes que já estão no aparelho (ex.: o que o usuário acabou de
  /// postar), para não baixá-los de volta.
  void remember(String mediaId, Uint8List bytes) {
    final previous = _cache.remove(mediaId);
    if (previous != null) _cachedBytes -= previous.length;
    _cache[mediaId] = bytes;
    _cachedBytes += bytes.length;
    while (_cachedBytes > maxCacheBytes && _cache.length > 1) {
      final oldest = _cache.keys.first;
      _cachedBytes -= _cache.remove(oldest)!.length;
    }
  }
}
