/// Konfigurasi aplikasi. Nilai bertanda `fromEnvironment` bisa diubah saat
/// build tanpa mengubah kode, misalnya:
///
/// ```bash
/// flutter run --dart-define=REGION_API_BASE=https://server-anda.id/api
/// ```
class AppConfig {
  AppConfig._();

  /// Alamat dasar API data wilayah. Bentuk endpoint:
  /// `{base}/provinces.json`, `{base}/regencies/{kode}.json`,
  /// `{base}/districts/{kode}.json`, `{base}/villages/{kode}.json`.
  ///
  /// Bawaan: wilayah.id, JSON statis gratis dengan kode dan nama mengikuti
  /// Kepmendagri No. 300.2.2-2138 Tahun 2025. Untuk produksi, sebaiknya
  /// salin data itu ke server sendiri dan arahkan alamat ini ke sana.
  static const String regionApiBase = String.fromEnvironment(
    'REGION_API_BASE',
    defaultValue: 'https://wilayah.id/api',
  );

  /// Prakiraan cuaca BMKG per kelurahan (parameter `adm4` = kode Kemendagri).
  static const String bmkgForecastUrl =
      'https://api.bmkg.go.id/publik/prakiraan-cuaca';

  /// RSS peringatan dini cuaca (nowcast) BMKG.
  static const String bmkgNowcastUrl = 'https://www.bmkg.go.id/alerts/nowcast/id';

  /// Ubin peta OpenStreetMap. Kebijakan OSM melarang pemakaian berat;
  /// untuk produksi pakai penyedia ubin sendiri atau berlangganan.
  static const String mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Nama paket (dipakai sebagai User-Agent ubin peta).
  static const String packageName = 'com.kelompok.warga_siaga';

  /// Saklar jaringan. Dibuat tidak `const` agar tes bisa mematikannya.
  static bool regionApiEnabled =
      const bool.fromEnvironment('REGION_API', defaultValue: true);
  static bool weatherApiEnabled =
      const bool.fromEnvironment('WEATHER_API', defaultValue: true);
  static bool mapTilesEnabled =
      const bool.fromEnvironment('MAP_TILES', defaultValue: true);
  static bool pushEnabled =
      const bool.fromEnvironment('PUSH', defaultValue: true);

  /// Batas waktu permintaan jaringan.
  static Duration httpTimeout = const Duration(seconds: 12);

  /// Dua laporan sejenis dalam jarak ini (dan dalam [duplicateWindow])
  /// dianggap kemungkinan ganda.
  static const double duplicateRadiusM = 150;
}
