import 'dart:async';
import 'package:geolocator/geolocator.dart';

enum LocationFailure { serviceOff, denied, deniedForever, timeout, unknown }

class LocationFix {
  final double lat;
  final double lng;
  final double accuracyM;
  final DateTime at;
  const LocationFix(this.lat, this.lng, this.accuracyM, this.at);
}

class LocationResult {
  final LocationFix? fix;
  final LocationFailure? failure;
  const LocationResult._(this.fix, this.failure);

  factory LocationResult.ok(LocationFix fix) => LocationResult._(fix, null);
  factory LocationResult.fail(LocationFailure f) => LocationResult._(null, f);

  bool get ok => fix != null;

  /// Penjelasan untuk pengguna bila gagal.
  String get message => switch (failure) {
        null => 'Lokasi berhasil diambil.',
        LocationFailure.serviceOff =>
          'GPS perangkat mati. Aktifkan layanan lokasi lalu coba lagi.',
        LocationFailure.denied =>
          'Izin lokasi ditolak. Izinkan lokasi agar laporan memiliki titik koordinat.',
        LocationFailure.deniedForever =>
          'Izin lokasi diblokir. Buka pengaturan aplikasi untuk mengizinkannya.',
        LocationFailure.timeout =>
          'Sinyal GPS belum didapat. Pindah ke tempat terbuka lalu coba lagi.',
        LocationFailure.unknown => 'Lokasi tidak dapat diambil saat ini.',
      };
}

/// Sumber lokasi. Diganti pada tes agar tidak memakai perangkat keras.
abstract class LocationProvider {
  Future<LocationResult> current();
  Future<void> openSettings(LocationFailure failure);
}

/// Lokasi dari GPS perangkat (paket geolocator).
class GeolocatorProvider implements LocationProvider {
  @override
  Future<LocationResult> current() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return LocationResult.fail(LocationFailure.serviceOff);

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return LocationResult.fail(LocationFailure.denied);
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationResult.fail(LocationFailure.deniedForever);
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      return LocationResult.ok(
        LocationFix(pos.latitude, pos.longitude, pos.accuracy, DateTime.now()),
      );
    } on TimeoutException {
      return LocationResult.fail(LocationFailure.timeout);
    } catch (_) {
      return LocationResult.fail(LocationFailure.unknown);
    }
  }

  @override
  Future<void> openSettings(LocationFailure failure) async {
    try {
      if (failure == LocationFailure.serviceOff) {
        await Geolocator.openLocationSettings();
      } else {
        await Geolocator.openAppSettings();
      }
    } catch (_) {
      // Tidak ada yang bisa dilakukan; pengguna membuka pengaturan manual.
    }
  }
}

class LocationService {
  LocationService._();

  static LocationProvider provider = GeolocatorProvider();

  static Future<LocationResult> current() => provider.current();

  static Future<void> openSettings(LocationFailure failure) =>
      provider.openSettings(failure);
}
