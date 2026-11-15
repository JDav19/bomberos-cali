import 'dart:math' as math;

const _radioTierraM = 6371000.0;

double _rad(double g) => g * math.pi / 180.0;

/// Distancia en metros entre dos coordenadas (formula de haversine).
double distanciaMetros(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _radioTierraM * math.asin(math.min(1, math.sqrt(a)));
}

/// Enlace que abre la ubicacion exacta en Google Maps.
Uri enlaceGoogleMaps(double lat, double lng) =>
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
