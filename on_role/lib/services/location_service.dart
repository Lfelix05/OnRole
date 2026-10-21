import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'geofence_engine.dart';

enum LocationAvailability { ready, serviceDisabled, denied, deniedForever }

/// Fonte de posições do app. Existe uma implementação com GPS real e outra
/// simulada, para testar as geocercas sem sair de casa.
abstract class LocationService {
  /// Garante serviço ligado e permissão concedida (pedindo se preciso).
  Future<LocationAvailability> prepare();

  Stream<LocationFix> watch();
}

class GpsLocationService implements LocationService {
  /// Só gera leitura nova depois de o usuário andar essa distância, o que
  /// poupa bateria enquanto ele está parado num local.
  static const int _distanceFilterMeters = 10;

  @override
  Future<LocationAvailability> prepare() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAvailability.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationAvailability.ready;
      case LocationPermission.deniedForever:
        return LocationAvailability.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAvailability.denied;
    }
  }

  @override
  Stream<LocationFix> watch() {
    return Geolocator.getPositionStream(locationSettings: _settings()).map(
      (position) => LocationFix(
        position: LatLng(position.latitude, position.longitude),
        accuracyMeters: position.accuracy,
        // O relógio do aparelho, e não o do fix, para o motor de geocercas
        // comparar tudo na mesma base de tempo que o tick().
        timestamp: DateTime.now(),
        isMocked: position.isMocked,
      ),
    );
  }

  /// Abre a tela certa do sistema para o usuário resolver o problema.
  Future<void> openSettings(LocationAvailability availability) async {
    if (availability == LocationAvailability.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  LocationSettings _settings() {
    if (kIsWeb) {
      return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: _distanceFilterMeters);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: _distanceFilterMeters,
          intervalDuration: const Duration(seconds: 10),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: _distanceFilterMeters,
          activityType: ActivityType.fitness,
          // Nesta fase o rastreamento é só com o app aberto.
          allowBackgroundLocationUpdates: false,
        );
      default:
        return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: _distanceFilterMeters);
    }
  }
}

/// Posição controlada à mão: no modo de simulação, cada toque no mapa vira
/// uma leitura de GPS.
class SimulatedLocationService implements LocationService {
  final _controller = StreamController<LocationFix>.broadcast();

  @override
  Future<LocationAvailability> prepare() async => LocationAvailability.ready;

  @override
  Stream<LocationFix> watch() => _controller.stream;

  void moveTo(LatLng position) {
    _controller.add(LocationFix(
      position: position,
      accuracyMeters: 5,
      timestamp: DateTime.now(),
      isMocked: true,
    ));
  }

  void dispose() => _controller.close();
}
