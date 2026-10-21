// O player de vídeo precisa de um arquivo (celular) ou de uma URL (web); os
// vídeos do OnRolê chegam como bytes do banco. Cada plataforma resolve isso
// num arquivo próprio.
export 'video_source_io.dart'
    if (dart.library.js_interop) 'video_source_web.dart';
