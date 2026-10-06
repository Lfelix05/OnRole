import 'dart:typed_data';

import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../data/repositories.dart';
import '../models/media.dart';
import 'video_source.dart';

/// Vídeos gravados pela câmera do app param sozinhos neste tempo.
const maxRecordingDuration = Duration(seconds: 15);

/// Vídeos da galeria podem ser mais longos, desde que caibam em
/// [maxMediaBytes].
const maxVideoDuration = Duration(seconds: 60);

// Fotos da galeria são reduzidas e comprimidas antes de subir (~150-300 KB).
const _maxImageSide = 1440.0;
const _imageQuality = 72;

/// Abre a galeria (fotos e vídeos). Lança [MediaException] para arquivos que
/// não cabem nos limites.
Future<List<MediaDraft>> pickFromGallery({int limit = maxPostMedia}) async {
  final picker = ImagePicker();
  final List<XFile> files;
  if (limit <= 1) {
    final file = await picker.pickMedia(
      maxWidth: _maxImageSide,
      maxHeight: _maxImageSide,
      imageQuality: _imageQuality,
    );
    files = file == null ? const [] : [file];
  } else {
    files = await picker.pickMultipleMedia(
      maxWidth: _maxImageSide,
      maxHeight: _maxImageSide,
      imageQuality: _imageQuality,
      limit: limit,
    );
  }
  return [for (final file in files.take(limit)) await draftFromFile(file)];
}

Future<MediaDraft> draftFromFile(XFile file) async {
  final bytes = await file.readAsBytes();
  final mimeType = file.mimeType ?? _mimeTypeFromName(file.name);
  return mimeType.startsWith('video/')
      ? videoDraft(bytes, mimeType: mimeType)
      : imageDraft(bytes, mimeType: mimeType);
}

Future<MediaDraft> imageDraft(
  Uint8List bytes, {
  String mimeType = 'image/jpeg',
}) async {
  _checkSize(bytes, isVideo: false);
  final image = await decodeImageFromList(bytes);
  final aspectRatio = image.width / image.height;
  image.dispose();
  return MediaDraft(
    bytes: bytes,
    kind: MediaKind.image,
    mimeType: mimeType,
    aspectRatio: aspectRatio,
  );
}

/// Abre o vídeo uma vez só para ler duração e proporção.
Future<MediaDraft> videoDraft(
  Uint8List bytes, {
  String mimeType = 'video/mp4',
}) async {
  _checkSize(bytes, isVideo: true);
  final controller = await videoControllerFromBytes(
    'rascunho_${DateTime.now().microsecondsSinceEpoch}',
    bytes,
    mimeType,
  );
  try {
    await controller.initialize();
    final duration = controller.value.duration;
    if (duration > maxVideoDuration) {
      throw MediaException(
        'Vídeo longo demais: o limite é de ${maxVideoDuration.inSeconds} s.',
      );
    }
    return MediaDraft(
      bytes: bytes,
      kind: MediaKind.video,
      mimeType: mimeType,
      aspectRatio: displayAspectRatio(controller.value),
      duration: duration,
    );
  } finally {
    await controller.dispose();
  }
}

/// Proporção com que o vídeo aparece na tela: muitos celulares gravam o
/// quadro "deitado" e só marcam a rotação no arquivo.
double displayAspectRatio(VideoPlayerValue value) {
  final quarterTurns = (value.rotationCorrection ~/ 90) % 4;
  return quarterTurns.isOdd ? 1 / value.aspectRatio : value.aspectRatio;
}

void _checkSize(Uint8List bytes, {required bool isVideo}) {
  if (bytes.length <= maxMediaBytes) return;
  final megabytes = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
  final limit = maxMediaBytes ~/ (1024 * 1024);
  throw MediaException(
    isVideo
        ? 'Vídeo grande demais (${megabytes.replaceAll('.', ',')} MB). O '
              'limite é $limit MB: grave pela câmera do OnRolê (até '
              '${maxRecordingDuration.inSeconds} s).'
        : 'Foto grande demais (${megabytes.replaceAll('.', ',')} MB). O '
              'limite é $limit MB.',
  );
}

String _mimeTypeFromName(String name) {
  return switch (name.split('.').last.toLowerCase()) {
    'mp4' || 'm4v' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    '3gp' => 'video/3gpp',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
  };
}
