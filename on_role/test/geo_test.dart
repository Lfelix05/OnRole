import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:on_role/services/geo.dart';

void main() {
  group('haversineDistance', () {
    const pracaMunicipal = LatLng(-19.53477, -40.62870);
    const areaDeEventos = LatLng(-19.53612, -40.63612);

    test('é zero para o mesmo ponto', () {
      expect(haversineDistance(pracaMunicipal, pracaMunicipal), 0);
    });

    test('um grau de latitude mede ~111,2 km', () {
      expect(haversineDistance(const LatLng(0, 0), const LatLng(1, 0)), closeTo(111195, 10));
    });

    test('é simétrica', () {
      expect(
        haversineDistance(pracaMunicipal, areaDeEventos),
        haversineDistance(areaDeEventos, pracaMunicipal),
      );
    });

    test('fica a menos de 0,5% da distância no elipsoide (Vincenty) em escala de cidade', () {
      final vincenty = const Distance(roundResult: false).as(LengthUnit.Meter, pracaMunicipal, areaDeEventos);
      expect(haversineDistance(pracaMunicipal, areaDeEventos), closeTo(vincenty, vincenty * 0.005));
    });
  });

  group('formatDistance', () {
    test('arredonda metros de 10 em 10', () {
      expect(formatDistance(347), '350 m');
    });

    test('usa quilômetros com vírgula a partir de 1 km', () {
      expect(formatDistance(1234), '1,2 km');
    });
  });
}
