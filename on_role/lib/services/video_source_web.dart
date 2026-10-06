import 'dart:typed_data';

import 'package:video_player/video_player.dart';

/// Na web, o vídeo vai para o player como uma data URL.
Future<VideoPlayerController> videoControllerFromBytes(
  String id,
  Uint8List bytes,
  String mimeType,
) async {
  return VideoPlayerController.networkUrl(
    Uri.dataFromBytes(bytes, mimeType: mimeType),
  );
}
