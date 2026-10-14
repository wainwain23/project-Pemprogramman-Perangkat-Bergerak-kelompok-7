import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../data/regions.dart';
import '../models.dart';

class RegionApiException implements Exception {
  final String message;
  RegionApiException(this.message);

  @override
  String toString() => message;
}

/// Sumber data wilayah berjenjang. Tingkat RW dan RT TIDAK tersedia di data
/// nasional (data resmi berhenti di kelurahan/desa); keduanya dikelola
/// aplikasi lewat [Regions.addLocalUnit].
abstract class RegionApi {
  Future<List<Region>> fetch(String? parentId, RegionLevel level);
}

/// Klien JSON statis: `{base}/provinces.json`, `{base}/regencies/{kode}.json`,
/// `{base}/districts/{kode}.json`, `{base}/villages/{kode}.json`.
/// Bentuk respons yang dikenali:
///  - `{"data": [{"code": "32.73", "name": "Kota Bandung"}], "meta": {...}}`
///    (wilayah.id, kode mengikuti Kemendagri)
///  - `[{"id": "3273", "name": "KOTA BANDUNG"}]` (format lain yang serupa)
class HttpRegionApi implements RegionApi {
  final String baseUrl;
  final http.Client _client;

  HttpRegionApi({String? baseUrl, http.Client? client})
      : baseUrl = _trimSlash(baseUrl ?? AppConfig.regionApiBase),
        _client = client ?? http.Client();

  static String _trimSlash(String s) =>
      s.endsWith('/') ? s.substring(0, s.length - 1) : s;

  /// Alamat endpoint untuk [parentId] dan [level] (dipisah agar mudah diuji).
  Uri endpoint(String? parentId, RegionLevel level) {
    final String path;
    switch (level) {
      case RegionLevel.provinsi:
        path = 'provinces.json';
      case RegionLevel.kota:
        path = 'regencies/${_need(parentId)}.json';
      case RegionLevel.kecamatan:
        path = 'districts/${_need(parentId)}.json';
      case RegionLevel.kelurahan:
        path = 'villages/${_need(parentId)}.json';
      case RegionLevel.rw:
      case RegionLevel.rt:
        throw RegionApiException(
            'RW/RT tidak tersedia di data wilayah nasional.');
    }
    return Uri.parse('$baseUrl/$path');
  }

  static String _need(String? parentId) {
    if (parentId == null || parentId.isEmpty) {
      throw RegionApiException('Wilayah induk belum dipilih.');
    }
    return parentId;
  }

  @override
  Future<List<Region>> fetch(String? parentId, RegionLevel level) async {
    final uri = endpoint(parentId, level);
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(AppConfig.httpTimeout);
    } catch (_) {
      throw RegionApiException('Gagal terhubung ke server wilayah.');
    }
    if (res.statusCode != 200) {
      throw RegionApiException('Server wilayah menjawab HTTP ${res.statusCode}.');
    }
    final dynamic body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw RegionApiException('Format data wilayah tidak dikenali.');
    }
    return parseRegions(body, parentId, level);
  }

  /// Mengubah JSON menjadi daftar [Region]. Entri yang rusak dilewati.
  static List<Region> parseRegions(
      dynamic body, String? parentId, RegionLevel level) {
    dynamic list = body;
    if (body is Map) list = body['data'];
    if (list is! List) {
      throw RegionApiException('Format data wilayah tidak dikenali.');
    }
    final out = <Region>[];
    for (final item in list) {
      if (item is! Map) continue;
      final rawCode = item['code'] ?? item['id'];
      final rawName = item['name'];
      if (rawCode == null || rawName == null) continue;
      final code = rawCode.toString().trim();
      final name = Regions.normalizeName(rawName.toString());
      if (code.isEmpty || name.isEmpty) continue;
      out.add(Region(code, name, level, parentId));
    }
    return out;
  }
}

/// Hasil memuat anak wilayah.
class RegionLoad {
  final List<Region> items;

  /// True bila daftar berasal dari server (bukan hanya data lokal).
  final bool remote;

  /// Pesan bila server tidak bisa dihubungi (data lokal dipakai sebagai gantinya).
  final String? error;
  const RegionLoad(this.items, {this.remote = false, this.error});
}

/// Memuat wilayah berjenjang dari server dengan cache dan cadangan lokal.
class RegionRepository {
  RegionRepository({RegionApi? api}) : _api = api ?? HttpRegionApi();

  /// Instans bersama; tes mengganti [api]-nya lewat konstruktor baru.
  static RegionRepository instance = RegionRepository();

  final RegionApi _api;
  final Map<String, List<Region>> _cache = {};

  static String _key(String? parentId, RegionLevel level) =>
      '${level.name}|${parentId ?? ''}';

  void clearCache() => _cache.clear();

  Future<RegionLoad> children(String? parentId, RegionLevel level) async {
    final local = Regions.children(parentId, level);
    final needsServer = level != RegionLevel.rw && level != RegionLevel.rt;
    if (!needsServer || !AppConfig.regionApiEnabled) {
      return RegionLoad(local);
    }
    if (level != RegionLevel.provinsi && parentId == null) {
      return const RegionLoad(<Region>[]);
    }
    final key = _key(parentId, level);
    final cached = _cache[key];
    if (cached != null) {
      return RegionLoad(_merge(cached, local), remote: true);
    }
    try {
      final fetched = await _api.fetch(parentId, level);
      Regions.register(fetched);
      _cache[key] = fetched;
      return RegionLoad(_merge(fetched, local), remote: true);
    } on RegionApiException catch (e) {
      return RegionLoad(local, error: '${e.message} Memakai data contoh.');
    } catch (_) {
      return RegionLoad(local,
          error: 'Gagal memuat data wilayah. Memakai data contoh.');
    }
  }

  /// Gabungan hasil server dan data lokal tanpa duplikat. Nama bawaan
  /// aplikasi menang atas nama server untuk id yang sama.
  List<Region> _merge(List<Region> remote, List<Region> local) {
    final byId = <String, Region>{};
    for (final r in remote) {
      byId[r.id] = Regions.byId(r.id) ?? r;
    }
    for (final r in local) {
      byId.putIfAbsent(r.id, () => r);
    }
    final out = byId.values.toList();
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }
}
