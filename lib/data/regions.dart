import '../geo.dart';
import '../models.dart';

/// Kode wilayah contoh (kode Kemendagri dari data wilayah.id, Kepmendagri
/// No. 300.2.2-2138 Tahun 2025). RW dan RT TIDAK ada di data nasional, jadi
/// id-nya dibuat dan dikelola oleh aplikasi.
class RegionIds {
  RegionIds._();

  // Jawa Barat, Kota Bandung
  static const String provJabar = '32';
  static const String kotaBandung = '32.73';
  static const String kecSukajadi = '32.73.07';
  static const String kelSukagalih = '32.73.07.1004';
  static const String kelPasteur = '32.73.07.1001';
  static const String rwSukagalih05 = 'rw-sg-05';
  static const String rwSukagalih06 = 'rw-sg-06';
  static const String rtSukagalih0503 = 'rt-sg-05-03';
  static const String rtSukagalih0504 = 'rt-sg-05-04';
  static const String rtSukagalih0601 = 'rt-sg-06-01';
  static const String rwPasteur02 = 'rw-ps-02';
  static const String rtPasteur0201 = 'rt-ps-02-01';

  // DKI Jakarta
  static const String provDki = '31';
  static const String kotaJaksel = '31.74';
  static const String kecKebayoranBaru = '31.74.07';
  static const String kelSenayan = '31.74.07.1006';
  static const String rwSenayan01 = 'rw-sn-01';
  static const String rtSenayan0102 = 'rt-sn-01-02';

  // Jawa Timur, Surabaya
  static const String provJatim = '35';
  static const String kotaSurabaya = '35.78';
  static const String kecGubeng = '35.78.08';
  static const String kelAirlangga = '35.78.08.1003';
  static const String rwAirlangga02 = 'rw-al-02';
  static const String rtAirlangga0201 = 'rt-al-02-01';

  // Sumatera Utara, Medan
  static const String provSumut = '12';
  static const String kotaMedan = '12.71';
  static const String kecMedanBaru = '12.71.17';
  static const String kelBabura = '12.71.17.1002';
  static const String rwBabura03 = 'rw-bb-03';
  static const String rtBabura0302 = 'rt-bb-03-02';
}

/// Registri wilayah. Berisi data contoh bawaan; wilayah yang dimuat dari API
/// (provinsi sampai kelurahan) serta RW/RT buatan pengurus didaftarkan ke sini
/// supaya seluruh logika (`chain`, `isWithin`, dst.) bekerja untuk wilayah
/// mana pun di Indonesia.
class Regions {
  Regions._();

  /// Akar virtual "seluruh Indonesia", dipakai Super Admin.
  static const String rootId = 'ID';

  static const List<Region> _seed = [
    // Jawa Barat - Bandung
    Region(RegionIds.provJabar, 'Jawa Barat', RegionLevel.provinsi, null),
    Region(RegionIds.kotaBandung, 'Kota Bandung', RegionLevel.kota,
        RegionIds.provJabar),
    Region(RegionIds.kecSukajadi, 'Sukajadi', RegionLevel.kecamatan,
        RegionIds.kotaBandung),
    Region(RegionIds.kelSukagalih, 'Sukagalih', RegionLevel.kelurahan,
        RegionIds.kecSukajadi),
    Region(RegionIds.kelPasteur, 'Pasteur', RegionLevel.kelurahan,
        RegionIds.kecSukajadi),
    Region(RegionIds.rwSukagalih05, 'RW 05', RegionLevel.rw,
        RegionIds.kelSukagalih),
    Region(RegionIds.rwSukagalih06, 'RW 06', RegionLevel.rw,
        RegionIds.kelSukagalih),
    Region(RegionIds.rtSukagalih0503, 'RT 03', RegionLevel.rt,
        RegionIds.rwSukagalih05),
    Region(RegionIds.rtSukagalih0504, 'RT 04', RegionLevel.rt,
        RegionIds.rwSukagalih05),
    Region(RegionIds.rtSukagalih0601, 'RT 01', RegionLevel.rt,
        RegionIds.rwSukagalih06),
    Region(RegionIds.rwPasteur02, 'RW 02', RegionLevel.rw, RegionIds.kelPasteur),
    Region(RegionIds.rtPasteur0201, 'RT 01', RegionLevel.rt,
        RegionIds.rwPasteur02),
    // DKI Jakarta
    Region(RegionIds.provDki, 'DKI Jakarta', RegionLevel.provinsi, null),
    Region(RegionIds.kotaJaksel, 'Kota Administrasi Jakarta Selatan',
        RegionLevel.kota, RegionIds.provDki),
    Region(RegionIds.kecKebayoranBaru, 'Kebayoran Baru', RegionLevel.kecamatan,
        RegionIds.kotaJaksel),
    Region(RegionIds.kelSenayan, 'Senayan', RegionLevel.kelurahan,
        RegionIds.kecKebayoranBaru),
    Region(RegionIds.rwSenayan01, 'RW 01', RegionLevel.rw, RegionIds.kelSenayan),
    Region(RegionIds.rtSenayan0102, 'RT 02', RegionLevel.rt,
        RegionIds.rwSenayan01),
    // Jawa Timur - Surabaya
    Region(RegionIds.provJatim, 'Jawa Timur', RegionLevel.provinsi, null),
    Region(RegionIds.kotaSurabaya, 'Kota Surabaya', RegionLevel.kota,
        RegionIds.provJatim),
    Region(RegionIds.kecGubeng, 'Gubeng', RegionLevel.kecamatan,
        RegionIds.kotaSurabaya),
    Region(RegionIds.kelAirlangga, 'Airlangga', RegionLevel.kelurahan,
        RegionIds.kecGubeng),
    Region(RegionIds.rwAirlangga02, 'RW 02', RegionLevel.rw,
        RegionIds.kelAirlangga),
    Region(RegionIds.rtAirlangga0201, 'RT 01', RegionLevel.rt,
        RegionIds.rwAirlangga02),
    // Sumatera Utara - Medan
    Region(RegionIds.provSumut, 'Sumatera Utara', RegionLevel.provinsi, null),
    Region(RegionIds.kotaMedan, 'Kota Medan', RegionLevel.kota,
        RegionIds.provSumut),
    Region(RegionIds.kecMedanBaru, 'Medan Baru', RegionLevel.kecamatan,
        RegionIds.kotaMedan),
    Region(RegionIds.kelBabura, 'Babura', RegionLevel.kelurahan,
        RegionIds.kecMedanBaru),
    Region(RegionIds.rwBabura03, 'RW 03', RegionLevel.rw, RegionIds.kelBabura),
    Region(RegionIds.rtBabura0302, 'RT 02', RegionLevel.rt, RegionIds.rwBabura03),
  ];

  /// Titik pusat perkiraan kelurahan contoh (untuk pusat peta dan data contoh).
  static const Map<String, GeoPoint> _centroids = {
    RegionIds.kelSukagalih: GeoPoint(-6.8872, 107.5925),
    RegionIds.kelPasteur: GeoPoint(-6.8940, 107.5950),
    RegionIds.kelSenayan: GeoPoint(-6.2272, 106.7990),
    RegionIds.kelAirlangga: GeoPoint(-7.2680, 112.7580),
    RegionIds.kelBabura: GeoPoint(3.5780, 98.6560),
  };

  static final Map<String, Region> _byId = {for (final r in _seed) r.id: r};
  static final Set<String> _seedIds = {for (final r in _seed) r.id};

  static List<Region> get all => List<Region>.unmodifiable(_byId.values);

  static Region? byId(String? id) => id == null ? null : _byId[id];

  /// Mendaftarkan wilayah (mis. hasil API). Wilayah yang sudah ada tidak
  /// ditimpa, sehingga nama contoh bawaan tetap utuh.
  static void register(Iterable<Region> regions) {
    for (final r in regions) {
      _byId.putIfAbsent(r.id, () => r);
    }
  }

  /// Menghapus semua wilayah selain data contoh (dipakai tes).
  static void resetToSeed() {
    _byId.removeWhere((id, _) => !_seedIds.contains(id));
  }

  static List<Region> children(String? parentId, RegionLevel level) {
    final out = _byId.values
        .where((r) => r.level == level && r.parentId == parentId)
        .toList();
    out.sort((a, b) => _compareNames(a.name, b.name));
    return out;
  }

  static final RegExp _numberedName = RegExp(r'^(.*?)(\d+)$');

  /// Urutan nama yang memperhatikan angka di belakang ("RT 2" < "RT 10").
  static int _compareNames(String a, String b) {
    final ma = _numberedName.firstMatch(a);
    final mb = _numberedName.firstMatch(b);
    if (ma != null && mb != null && ma.group(1) == mb.group(1)) {
      return int.parse(ma.group(2)!).compareTo(int.parse(mb.group(2)!));
    }
    return a.compareTo(b);
  }

  /// Rantai wilayah dari provinsi sampai wilayah itu sendiri.
  static List<Region> chain(String id) {
    final out = <Region>[];
    var cur = byId(id);
    var guard = 0;
    while (cur != null && guard++ < 12) {
      out.insert(0, cur);
      cur = byId(cur.parentId);
    }
    return out;
  }

  /// Apakah [id] berada di dalam (atau sama dengan) [ancestorId].
  /// [rootId] mencakup seluruh wilayah.
  static bool isWithin(String id, String ancestorId) {
    if (ancestorId == rootId) return true;
    return chain(id).any((r) => r.id == ancestorId);
  }

  static String? ancestorAtLevel(String id, RegionLevel level) {
    for (final r in chain(id)) {
      if (r.level == level) return r.id;
    }
    return null;
  }

  /// Tingkat wilayah, atau null untuk [rootId]/id tak dikenal.
  static RegionLevel? levelOf(String id) => byId(id)?.level;

  static String label(String id) {
    if (id == rootId) return 'Seluruh Indonesia';
    final r = byId(id);
    if (r == null) return '-';
    switch (r.level) {
      case RegionLevel.provinsi:
        return 'Prov. ${r.name}';
      case RegionLevel.kecamatan:
        return 'Kec. ${r.name}';
      case RegionLevel.kelurahan:
        return 'Kel. ${r.name}';
      default:
        return r.name;
    }
  }

  /// Contoh: "RT 03/RW 05, Kel. Sukagalih".
  static String shortName(String id) {
    if (id == rootId) return 'Seluruh Indonesia';
    final r = byId(id);
    if (r == null) return '-';
    if (r.level == RegionLevel.rt) {
      final rw = byId(r.parentId);
      final kel = rw == null ? null : byId(rw.parentId);
      final kelText = kel == null ? '' : ', Kel. ${kel.name}';
      return '${r.name}/${rw?.name ?? ''}$kelText';
    }
    return label(id);
  }

  static String fullName(String id) {
    if (id == rootId) return 'Seluruh Indonesia';
    return chain(id).reversed.map((r) => label(r.id)).join(', ');
  }

  /// Titik pusat perkiraan wilayah (dari leluhur terdekat yang diketahui).
  static GeoPoint? centroid(String id) {
    for (final r in chain(id).reversed) {
      final c = _centroids[r.id];
      if (c != null) return c;
    }
    return null;
  }

  /// Membuat RW (di bawah kelurahan) atau RT (di bawah RW) baru. Nomor
  /// diisi angka 1-999. Mengembalikan wilayah yang sudah ada bila kembar,
  /// atau null bila masukan tidak valid.
  static Region? addLocalUnit(String parentId, String number) {
    final parent = byId(parentId);
    if (parent == null) return null;
    final RegionLevel level;
    if (parent.level == RegionLevel.kelurahan) {
      level = RegionLevel.rw;
    } else if (parent.level == RegionLevel.rw) {
      level = RegionLevel.rt;
    } else {
      return null;
    }
    final n = int.tryParse(number.trim());
    if (n == null || n < 1 || n > 999) return null;
    final padded = n.toString().padLeft(2, '0');
    final name = '${level == RegionLevel.rw ? 'RW' : 'RT'} $padded';
    for (final r in children(parentId, level)) {
      if (r.name == name) return r;
    }
    final prefix = level == RegionLevel.rw ? 'rw' : 'rt';
    final region = Region('$prefix-$parentId-$padded', name, level, parentId);
    _byId[region.id] = region;
    return region;
  }

  /// Huruf kapital semua ("JAWA BARAT") diubah ke "Jawa Barat". Nama yang
  /// sudah bercampur huruf besar-kecil dibiarkan.
  static String normalizeName(String raw) {
    final name = raw.trim();
    if (name.isEmpty || name != name.toUpperCase()) return name;
    const keep = {'DKI', 'DI', 'NTB', 'NTT', 'RI', 'IV', 'III', 'II'};
    return name
        .split(RegExp(r'\s+'))
        .map((w) => keep.contains(w)
            ? w
            : (w.isEmpty ? w : w[0] + w.substring(1).toLowerCase()))
        .join(' ');
  }
}
