import 'dart:math';

/// Titik koordinat sederhana (tanpa bergantung pada paket peta).
class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => formatCoord(lat, lng);
}

const double kEarthRadiusM = 6371000;

double _rad(double deg) => deg * pi / 180;

/// Jarak lingkaran besar (meter) antara dua koordinat (rumus haversine).
double haversineM(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = pow(sin(dLat / 2), 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * pow(sin(dLon / 2), 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return kEarthRadiusM * c;
}

/// Koordinat yang masuk akal (bukan 0,0 dan dalam rentang bumi).
bool isValidCoord(double? lat, double? lng) {
  if (lat == null || lng == null) return false;
  if (lat.isNaN || lng.isNaN) return false;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return false;
  if (lat == 0 && lng == 0) return false;
  return true;
}

String formatCoord(double lat, double lng) =>
    '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

/// Jarak ramah baca: "85 m" atau "1,2 km".
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km < 10 ? 1 : 0).replaceAll('.', ',')} km';
}
