import 'package:url_launcher/url_launcher.dart';

/// Panggilan telepon sekali ketuk (membuka aplikasi telepon dengan nomor terisi).
class CallService {
  CallService._();

  /// Pembuka tautan. Diganti pada tes.
  static Future<bool> Function(Uri uri) launcher = _defaultLaunch;

  static Future<bool> _defaultLaunch(Uri uri) async {
    try {
      if (!await canLaunchUrl(uri)) return false;
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  /// Hanya angka, '+', '*', dan '#' yang dipertahankan.
  static String normalize(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9+*#]'), '');

  /// Mengembalikan false bila nomor kosong atau perangkat tidak bisa menelepon.
  static Future<bool> call(String phone) {
    final number = normalize(phone);
    if (number.isEmpty) return Future<bool>.value(false);
    return launcher(Uri(scheme: 'tel', path: number));
  }
}
