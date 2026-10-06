import 'dart:typed_data';

enum MediaKind { image, video }

/// Foto ou vídeo já guardado no banco. Os bytes ficam divididos em pedaços
/// (ver MediaRepository); aqui vai só o necessário para exibir e baixar.
class MediaRef {
  const MediaRef({
    required this.id,
    required this.kind,
    required this.mimeType,
    required this.chunkCount,
    required this.aspectRatio,
    this.duration,
  });

  final String id;
  final MediaKind kind;
  final String mimeType;

  /// Em quantos pedaços os bytes foram divididos.
  final int chunkCount;

  /// Largura dividida pela altura.
  final double aspectRatio;

  /// Só para vídeos.
  final Duration? duration;

  bool get isVideo => kind == MediaKind.video;

  factory MediaRef.fromJson(Map<String, dynamic> json) {
    final durationMs = json['durationMs'] as num?;
    return MediaRef(
      id: json['id'],
      kind: MediaKind.values.byName(json['kind']),
      mimeType: json['mimeType'],
      chunkCount: (json['chunkCount'] as num).toInt(),
      aspectRatio: (json['aspectRatio'] as num).toDouble(),
      duration: durationMs == null
          ? null
          : Duration(milliseconds: durationMs.toInt()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'mimeType': mimeType,
      'chunkCount': chunkCount,
      'aspectRatio': aspectRatio,
      'durationMs': duration?.inMilliseconds,
    };
  }
}

/// Foto ou vídeo escolhido ou capturado, ainda só no aparelho.
class MediaDraft {
  const MediaDraft({
    required this.bytes,
    required this.kind,
    required this.mimeType,
    required this.aspectRatio,
    this.duration,
  });

  final Uint8List bytes;
  final MediaKind kind;
  final String mimeType;
  final double aspectRatio;
  final Duration? duration;

  bool get isVideo => kind == MediaKind.video;
}
