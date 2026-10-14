import 'package:flutter_test/flutter_test.dart';
import 'package:warga_siaga/data/regions.dart';
import 'package:warga_siaga/models.dart';

void main() {
  setUp(Regions.resetToSeed);

  test('RT 03 berada di dalam Kota Bandung, bukan Surabaya', () {
    expect(Regions.isWithin(RegionIds.rtSukagalih0503, RegionIds.kotaBandung),
        isTrue);
    expect(Regions.isWithin(RegionIds.rtSukagalih0503, RegionIds.kotaSurabaya),
        isFalse);
  });

  test('Mencari wilayah induk berdasarkan tingkat', () {
    expect(
        Regions.ancestorAtLevel(
            RegionIds.rtSukagalih0503, RegionLevel.kelurahan),
        RegionIds.kelSukagalih);
    expect(
        Regions.ancestorAtLevel(
            RegionIds.rtSukagalih0503, RegionLevel.provinsi),
        RegionIds.provJabar);
  });

  test('Id wilayah memakai kode Kemendagri', () {
    expect(RegionIds.provJabar, '32');
    expect(RegionIds.kotaBandung, '32.73');
    expect(RegionIds.kelSukagalih.startsWith('${RegionIds.kecSukajadi}.'),
        isTrue);
  });

  test('Nama singkat dan nama lengkap wilayah', () {
    expect(Regions.shortName(RegionIds.rtSukagalih0503),
        'RT 03/RW 05, Kel. Sukagalih');
    expect(Regions.fullName(RegionIds.rtSukagalih0503).contains('Kota Bandung'),
        isTrue);
  });

  test('Setiap wilayah punya induk yang valid', () {
    for (final r in Regions.all) {
      if (r.parentId != null) {
        expect(Regions.byId(r.parentId), isNotNull, reason: r.id);
      }
    }
  });

  test('RW/RT lokal ditambah di bawah induk yang tepat, tanpa duplikat', () {
    final rw = Regions.addLocalUnit(RegionIds.kelSukagalih, '9');
    expect(rw, isNotNull);
    expect(rw!.level, RegionLevel.rw);
    expect(rw.name, 'RW 09');
    expect(Regions.addLocalUnit(RegionIds.kelSukagalih, '09')?.id, rw.id);

    final rt = Regions.addLocalUnit(rw.id, '2');
    expect(rt?.level, RegionLevel.rt);
    expect(Regions.isWithin(rt!.id, RegionIds.kotaBandung), isTrue);

    // Induk yang salah atau nomor tidak valid ditolak.
    expect(Regions.addLocalUnit(RegionIds.kotaBandung, '1'), isNull);
    expect(Regions.addLocalUnit(RegionIds.kelSukagalih, '0'), isNull);
    expect(Regions.addLocalUnit(RegionIds.kelSukagalih, 'abc'), isNull);

    Regions.resetToSeed();
    expect(Regions.byId(rw.id), isNull);
  });
}
