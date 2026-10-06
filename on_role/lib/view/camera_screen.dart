import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../data/repositories.dart';
import '../models/media.dart';
import '../services/media_drafts.dart';
import '../theme/app_theme.dart';

/// Câmera do OnRolê, no estilo dos stories: toque para foto, segure para
/// vídeo. Grava em 480p e para em 15 s, para o vídeo caber no banco gratuito.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  /// Abre a câmera e devolve o que foi capturado (ou null se cancelar).
  static Future<MediaDraft?> open(BuildContext context) {
    return Navigator.of(context).push<MediaDraft>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CameraCaptureScreen(),
      ),
    );
  }

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _recordingProgress = AnimationController(
    vsync: this,
    duration: maxRecordingDuration,
  );
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  CameraController? _controller;
  String? _error;
  bool _busy = false;
  bool _recording = false;
  Timer? _recordingLimit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'Nenhuma câmera encontrada neste aparelho.');
        return;
      }
      final back = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      _cameraIndex = back == -1 ? 0 : back;
      await _open(_cameras[_cameraIndex]);
    } on CameraException catch (error) {
      if (mounted) setState(() => _error = _describe(error));
    }
  }

  Future<void> _open(CameraDescription camera) async {
    final previous = _controller;
    setState(() => _controller = null);
    await previous?.dispose();

    // No Android o preset define a qualidade do vídeo (480p); a taxa de bits
    // vale no iPhone.
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      videoBitrate: 1500000,
      audioBitrate: 64000,
    );
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } on CameraException catch (error) {
      await controller.dispose();
      if (mounted) setState(() => _error = _describe(error));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A câmera é liberada em segundo plano e reaberta na volta.
    if (state == AppLifecycleState.inactive) {
      final controller = _controller;
      if (controller != null && !_recording) {
        setState(() => _controller = null);
        controller.dispose();
      }
    } else if (state == AppLifecycleState.resumed &&
        _controller == null &&
        _cameras.isNotEmpty) {
      _open(_cameras[_cameraIndex]);
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || _busy || _recording) return;
    setState(() => _busy = true);
    try {
      final file = await controller.takePicture();
      final draft = await imageDraft(await file.readAsBytes());
      if (mounted) Navigator.pop(context, draft);
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null || _busy || _recording) return;
    try {
      await controller.startVideoRecording();
      setState(() => _recording = true);
      _recordingProgress.forward(from: 0);
      _recordingLimit = Timer(maxRecordingDuration, _stopRecording);
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (controller == null || !_recording) return;
    _recordingLimit?.cancel();
    _recordingProgress.stop();
    setState(() {
      _recording = false;
      _busy = true;
    });
    try {
      final file = await controller.stopVideoRecording();
      final draft = await videoDraft(
        await file.readAsBytes(),
        mimeType: file.mimeType ?? 'video/mp4',
      );
      if (mounted) Navigator.pop(context, draft);
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final drafts = await pickFromGallery(limit: 1);
      if (drafts.isNotEmpty && mounted) Navigator.pop(context, drafts.first);
    } catch (error) {
      _fail(error);
    }
  }

  void _switchCamera() {
    if (_cameras.length < 2 || _recording || _busy) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    _open(_cameras[_cameraIndex]);
  }

  void _fail(Object error) {
    debugPrint('CameraCaptureScreen: $error');
    if (!mounted) return;
    setState(() {
      _busy = false;
      _recording = false;
    });
    final message = error is MediaException
        ? error.message
        : error is CameraException
        ? _describe(error)
        : 'Não foi possível capturar. Tente de novo.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _describe(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Permita o acesso à câmera nas configurações do celular.';
      case 'AudioAccessDenied':
      case 'AudioAccessDeniedWithoutPrompt':
      case 'AudioAccessRestricted':
        return 'Permita o acesso ao microfone para gravar vídeos.';
      default:
        return 'Não foi possível abrir a câmera (${error.code}).';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingLimit?.cancel();
    _recordingProgress.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            _FullScreenPreview(controller: controller)
          else if (_error != null)
            _CameraError(message: _error!, onPickFromGallery: _pickFromGallery)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  if (_cameras.length > 1)
                    IconButton(
                      tooltip: 'Trocar câmera',
                      onPressed: _switchCamera,
                      icon: const Icon(
                        Icons.cameraswitch_outlined,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _recording
                          ? 'Gravando... solte para terminar'
                          : 'Toque para foto · segure para vídeo',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          tooltip: 'Galeria',
                          onPressed: _busy || _recording
                              ? null
                              : _pickFromGallery,
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        _ShutterButton(
                          progress: _recordingProgress,
                          recording: _recording,
                          busy: _busy,
                          onTap: _takePhoto,
                          onHoldStart: _startRecording,
                          onHoldEnd: _stopRecording,
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Preview ocupando a tela toda (corta as bordas em vez de deixar faixas).
class _FullScreenPreview extends StatelessWidget {
  const _FullScreenPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    var scale =
        MediaQuery.sizeOf(context).aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(child: CameraPreview(controller)),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({
    required this.progress,
    required this.recording,
    required this.busy,
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final Animation<double> progress;
  final bool recording;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (_) => onHoldStart(),
      onLongPressEnd: (_) => onHoldEnd(),
      child: SizedBox(
        width: 86,
        height: 86,
        child: AnimatedBuilder(
          animation: progress,
          builder: (context, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: recording ? progress.value : 0,
                    strokeWidth: 5,
                    color: const Color(0xFFEF4444),
                    backgroundColor: Colors.white38,
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: recording ? 52 : 68,
                  height: recording ? 52 : 68,
                  decoration: BoxDecoration(
                    color: recording ? const Color(0xFFEF4444) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onPickFromGallery});

  final String message;
  final VoidCallback onPickFromGallery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onPickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Escolher da galeria'),
            ),
          ],
        ),
      ),
    );
  }
}
