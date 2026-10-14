import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../data/regions.dart';
import '../models.dart';

/// Wajib ditampilkan di aplikasi yang memakai data BMKG.
const String kBmkgAttribution = 'Sumber data: BMKG (Badan Meteorologi, Klimatologi, dan Geofisika)';

class WeatherAlert {
  final String title;
  final String detail;
  final Severity severity;
  final String source;
  final DateTime? issuedAt;

  /// True untuk data contoh (bukan dari instansi).
  final bool sample;
  const WeatherAlert({
    required this.title,
    required this.detail,
    required this.severity,
    required this.source,
    this.issuedAt,
    this.sample = false,
  });
}

class WeatherReport {
  final List<WeatherAlert> alerts;

  /// Pesan bila data instansi tidak bisa dimuat.
  final String? error;
  final DateTime fetchedAt;
  WeatherReport(this.alerts, {this.error, DateTime? fetchedAt})
      : fetchedAt = fetchedAt ?? DateTime.now();
}

abstract class WeatherSource {
  Future<WeatherReport> load(String areaId);
}

/// Data peringatan dini dan prakiraan cuaca dari BMKG (data terbuka):
///  - RSS peringatan dini cuaca per provinsi (nowcast)
///  - prakiraan cuaca per kelurahan (parameter `adm4` = kode Kemendagri)
/// Batas akses BMKG: 60 permintaan per menit per IP.
class BmkgWeatherSource implements WeatherSource {
  final http.Client _client;
  BmkgWeatherSource({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<WeatherReport> load(String areaId) async {
    final alerts = <WeatherAlert>[];
    final errors = <String>[];

    final prov = Regions.ancestorAtLevel(areaId, RegionLevel.provinsi);
    final provName = prov == null ? null : Regions.byId(prov)?.name;
    if (provName != null) {
      try {
        alerts.addAll(await _nowcast(provName));
      } catch (_) {
        errors.add('peringatan dini BMKG');
      }
    }

    final kel = Regions.ancestorAtLevel(areaId, RegionLevel.kelurahan);
    // Kode Kemendagri bertitik (32.73.07.1004). Id buatan sendiri dilewati.
    if (kel != null && RegExp(r'^\d{2}\.\d{2}\.\d{2}\.\d{4}$').hasMatch(kel)) {
      try {
        final f = await _forecast(kel);
        if (f != null) alerts.add(f);
      } catch (_) {
        errors.add('prakiraan cuaca BMKG');
      }
    }

    return WeatherReport(
      alerts,
      error: errors.isEmpty
          ? null
          : 'Data ${errors.join(' dan ')} belum dapat dimuat.',
    );
  }

  Future<String> _get(String url) async {
    final res = await _client.get(Uri.parse(url)).timeout(AppConfig.httpTimeout);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return utf8.decode(res.bodyBytes);
  }

  Future<List<WeatherAlert>> _nowcast(String provinceName) async {
    final xml = await _get(AppConfig.bmkgNowcastUrl);
    return parseNowcast(xml, provinceName);
  }

  /// Mengurai RSS peringatan dini dan menyaring yang menyebut provinsi ini.
  static List<WeatherAlert> parseNowcast(String xml, String provinceName) {
    final out = <WeatherAlert>[];
    final prov = provinceName.toLowerCase();
    final items = RegExp(r'<item>([\s\S]*?)</item>').allMatches(xml);
    for (final m in items) {
      final block = m.group(1) ?? '';
      final title = _tag(block, 'title');
      final desc = _tag(block, 'description');
      final hay = '$title $desc'.toLowerCase();
      if (!hay.contains(prov)) continue;
      final severity = hay.contains('ekstrem')
          ? Severity.bahaya
          : Severity.waspada;
      out.add(WeatherAlert(
        title: title.isEmpty ? 'Peringatan dini cuaca' : title,
        detail: desc,
        severity: severity,
        source: 'BMKG - Peringatan Dini Cuaca',
        issuedAt: _parseRfc1123(_tag(block, 'pubDate')),
      ));
    }
    return out;
  }

  static String _tag(String block, String tag) {
    final m = RegExp('<$tag>([\\s\\S]*?)</$tag>').firstMatch(block);
    if (m == null) return '';
    var v = m.group(1) ?? '';
    v = v.replaceAll('<![CDATA[', '').replaceAll(']]>', '');
    v = v.replaceAll(RegExp(r'<[^>]+>'), ' ');
    return v.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static DateTime? _parseRfc1123(String s) {
    if (s.isEmpty) return null;
    try {
      const months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };
      final m = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2})')
          .firstMatch(s);
      if (m == null) return null;
      final month = months[m.group(2)!.toLowerCase()];
      if (month == null) return null;
      return DateTime(int.parse(m.group(3)!), month, int.parse(m.group(1)!),
          int.parse(m.group(4)!), int.parse(m.group(5)!));
    } catch (_) {
      return null;
    }
  }

  Future<WeatherAlert?> _forecast(String kelurahanCode) async {
    final body = await _get('${AppConfig.bmkgForecastUrl}?adm4=$kelurahanCode');
    return parseForecast(jsonDecode(body), now: DateTime.now());
  }

  /// Mencari prakiraan 24 jam ke depan yang memuat hujan lebat/petir. Struktur
  /// JSON dijelajahi rekursif (kunci `weather_desc` dan `local_datetime`)
  /// sehingga tetap bekerja walau pembungkusnya berubah.
  static WeatherAlert? parseForecast(dynamic json, {required DateTime now}) {
    final entries = <Map<String, dynamic>>[];
    void walk(dynamic node) {
      if (node is Map) {
        if (node['weather_desc'] != null && node['local_datetime'] != null) {
          entries.add(Map<String, dynamic>.from(node));
        } else {
          node.values.forEach(walk);
        }
      } else if (node is List) {
        node.forEach(walk);
      }
    }

    walk(json);
    if (entries.isEmpty) return null;

    final upcoming = <(DateTime, String)>[];
    for (final e in entries) {
      final t = DateTime.tryParse(
          e['local_datetime'].toString().replaceFirst(' ', 'T'));
      if (t == null) continue;
      // Waktu BMKG adalah waktu setempat tanpa zona; dianggap waktu perangkat.
      if (t.isBefore(now.subtract(const Duration(hours: 3)))) continue;
      if (t.isAfter(now.add(const Duration(hours: 24)))) continue;
      upcoming.add((t, e['weather_desc'].toString()));
    }
    upcoming.sort((a, b) => a.$1.compareTo(b.$1));

    final extreme = upcoming.where((u) {
      final d = u.$2.toLowerCase();
      return d.contains('lebat') || d.contains('petir');
    }).toList();
    if (extreme.isEmpty) return null;

    final first = extreme.first;
    final last = extreme.last;
    final range = extreme.length == 1
        ? 'sekitar pukul ${clock(first.$1)}'
        : 'pukul ${clock(first.$1)} sampai ${clock(last.$1)}';
    return WeatherAlert(
      title: 'Prakiraan: ${first.$2}',
      detail: 'BMKG memprakirakan ${first.$2.toLowerCase()} $range di '
          'kelurahan Anda dalam 24 jam ke depan. Waspadai genangan, pohon '
          'tumbang, dan sambaran petir.',
      severity: Severity.waspada,
      source: 'BMKG - Prakiraan Cuaca',
      issuedAt: now,
    );
  }
}

/// Data contoh untuk demo tanpa internet. SELALU ditandai sebagai contoh.
class SampleWeatherSource implements WeatherSource {
  @override
  Future<WeatherReport> load(String areaId) async {
    return WeatherReport([
      WeatherAlert(
        title: 'Contoh: potensi hujan lebat disertai petir',
        detail:
            'Ini data contoh untuk demo, bukan data BMKG. Pada pemakaian nyata, '
            'banner ini menampilkan peringatan dini dan prakiraan BMKG untuk kelurahan Anda.',
        severity: Severity.waspada,
        source: 'Contoh',
        issuedAt: DateTime.now(),
        sample: true,
      ),
    ]);
  }
}

class WeatherService {
  WeatherService._();

  static WeatherSource? _override;
  static final Map<String, WeatherReport> _cache = {};
  static const Duration cacheTtl = Duration(minutes: 10);

  /// Mengganti sumber data (tes). Null mengembalikan pilihan otomatis.
  static void useSource(WeatherSource? source) {
    _override = source;
    _cache.clear();
  }

  static WeatherSource get _source =>
      _override ??
      (AppConfig.weatherApiEnabled ? BmkgWeatherSource() : SampleWeatherSource());

  static Future<WeatherReport> load(String areaId, {bool force = false}) async {
    final kel = Regions.ancestorAtLevel(areaId, RegionLevel.kelurahan) ?? areaId;
    final cached = _cache[kel];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < cacheTtl) {
      return cached;
    }
    try {
      final report = await _source.load(areaId);
      _cache[kel] = report;
      return report;
    } catch (_) {
      return WeatherReport(const <WeatherAlert>[],
          error: 'Data cuaca belum dapat dimuat.');
    }
  }
}
