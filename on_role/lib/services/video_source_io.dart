import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// Grava os bytes num arquivo temporário (reaproveitado pelo [id]) e cria o
/// player a partir dele.
Future<VideoPlayerController> videoControllerFromBytes(
  String id,
  Uint8List bytes,
  String mimeType,
) async {
  final directory = await getTemporaryDirectory();
  final extension = mimeType.contains('quicktime') ? 'mov' : 'mp4';
  final file = File('${directory.path}/onrole_video_$id.$extension');
  if (!await file.exists() || await file.length() != bytes.length) {
    await file.writeAsBytes(bytes, flush: true);
  }
  return VideoPlayerController.file(file);
}
