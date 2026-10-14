import 'package:flutter_test/flutter_test.dart';
import 'package:warga_siaga/app_state.dart';
import 'package:warga_siaga/data/regions.dart';
import 'package:warga_siaga/models.dart';
import 'package:warga_siaga/safety_models.dart';
import 'package:warga_siaga/services/push_service.dart';

void main() {
  final s = AppState.instance;

  setUp(() => s.resetForTests());

  test('Login gagal dengan sandi salah', () {
    expect(s.login('warga@demo.id', 'salah'), isNotNull);
    expect(s.loggedIn, isFalse);
  });

  test('Ketua RT hanya bisa memverifikasi laporan di RT-nya', () {
    expect(s.login('rt@demo.id', '123456'), isNull);
    final rt03 = s.reportById('r3')!; // RT 03
    final rt04 = s.reportById('r2')!; // RT 04
    expect(s.canModerate(rt03), isTrue);
    expect(s.canModerate(rt04), isFalse);

    s.setStatus(rt03, ReportStatus.terverifikasi, severity: Severity.waspada);
    expect(rt03.status, ReportStatus.terverifikasi);
    expect(rt03.severity, Severity.waspada);
  });

  test('Warga biasa tidak bisa memverifikasi', () {
    s.login('warga@demo.id', '123456');
    final r = s.reportById('r4')!;
    expect(s.canModerate(r), isFalse);
    s.setStatus(r, ReportStatus.terverifikasi);
    expect(r.status, ReportStatus.menunggu);
  });

  test('Laporan terverifikasi otomatis setelah cukup konfirmasi warga', () {
    s.login('warga@demo.id', '123456');
    final r = s.reportById('r4')!; // sudah 2 konfirmasi
    expect(s.confirmReport(r), isTrue);
    expect(r.status, ReportStatus.terverifikasi);
    expect(s.confirmReport(r), isFalse); // tidak bisa konfirmasi dua kali
  });

  test('Cakupan laporan mengikuti wilayah pengguna', () {
    s.login('warga@demo.id', '123456');
    final kota = s.reportsInScope(ReportScope.kota).map((r) => r.id).toList();
    expect(kota.contains('r1'), isTrue);
    expect(kota.contains('r6'), isFalse); // Jakarta
    expect(kota.contains('r7'), isFalse); // Surabaya
  });

  test('Laporan offline menunggu sinkron lalu terkirim saat online', () {
    s.login('warga@demo.id', '123456');
    s.setOffline(true);
    final err = s.addReport(
      category: 'Banjir',
      description: 'Genangan di depan rumah warga',
      location: 'Depan rumah',
      lat: -6.8870,
      lng: 107.5920,
    );
    expect(err, isNull);
    expect(s.pendingCount, 1);
    final synced = s.setOffline(false);
    expect(synced, 1);
    expect(s.pendingCount, 0);
  });

  test('Admin menyetujui Ketua RT di wilayahnya', () {
    s.login('admin@demo.id', '123456');
    final pending = s.pendingApprovals;
    expect(pending.any((u) => u.email == 'sari@demo.id'), isTrue);
    s.approve(pending.firstWhere((u) => u.email == 'sari@demo.id'));
    expect(s.pendingApprovals.any((u) => u.email == 'sari@demo.id'), isFalse);
  });

  test('Login dikunci sementara setelah terlalu banyak percobaan gagal', () {
    // Email tersendiri agar tidak mengganggu tes lain.
    for (var i = 0; i < AppState.maxLoginAttempts - 1; i++) {
      expect(s.login('kunci@demo.id', 'salah'), 'Email atau kata sandi salah');
    }
    final locked = s.login('kunci@demo.id', 'salah');
    expect(locked, contains('dikunci'));
    // Selama terkunci, bahkan percobaan berikutnya ditolak.
    expect(s.login('kunci@demo.id', 'salah'), contains('Coba lagi'));
    expect(s.loggedIn, isFalse);
  });

  test('Reset kata sandi dengan kode', () {
    expect(s.requestPasswordReset('tidakada@demo.id'), isNull);

    final code = s.requestPasswordReset('warga@demo.id')!;
    expect(s.confirmPasswordReset('warga@demo.id', '000000', 'baru123'),
        'Kode salah');
    expect(s.confirmPasswordReset('warga@demo.id', code, '123'),
        contains('minimal 6'));
    expect(s.confirmPasswordReset('warga@demo.id', code, 'baru123'), isNull);

    expect(s.login('warga@demo.id', '123456'), isNotNull); // sandi lama tak berlaku
    expect(s.login('warga@demo.id', 'baru123'), isNull);

    // Kembalikan agar tes lain tetap memakai sandi demo.
    final code2 = s.requestPasswordReset('warga@demo.id')!;
    expect(s.confirmPasswordReset('warga@demo.id', code2, '123456'), isNull);
    // Kode hanya sekali pakai.
    expect(s.confirmPasswordReset('warga@demo.id', code2, 'lain123'),
        isNotNull);
  });

  test('Deteksi laporan ganda berdasarkan jarak koordinat', () {
    s.login('warga@demo.id', '123456');
    final r3 = s.reportById('r3')!; // Jalan rusak, 5 jam lalu, masih aktif
    // Tanpa koordinat: dipakai kesamaan RT.
    expect(s.findPossibleDuplicate('Jalan rusak')?.id, 'r3');
    // Titik yang sama: ganda.
    expect(
        s.findPossibleDuplicate('Jalan rusak', lat: r3.lat, lng: r3.lng)?.id,
        'r3');
    // Titik jauh (Jakarta): bukan ganda walau kategorinya sama.
    expect(s.findPossibleDuplicate('Jalan rusak', lat: -6.2268, lng: 106.8),
        isNull);
    // Kategori lain di RT lain / sudah lewat jendela waktu.
    expect(s.findPossibleDuplicate('Sampah'), isNull);
    expect(s.findPossibleDuplicate('Lampu mati'), isNull);
  });

  test('Konfirmasi hanya dari warga satu kelurahan', () {
    final luar = AppUser(
      name: 'Warga Pasteur',
      email: 'luar@demo.id',
      phone: '0812-0000-7777',
      password: '123456',
      role: UserRole.warga,
      areaId: RegionIds.rtPasteur0201, // Kel. Pasteur, bukan Sukagalih
    );
    expect(s.register(luar), isNull);
    final r = s.reportById('r3')!; // RT 03 Sukagalih
    expect(s.canConfirm(r), isFalse);
    final before = r.confirmations;
    expect(s.confirmReport(r), isFalse);
    expect(r.confirmations, before);
  });

  test('Status laporan hanya boleh mengikuti alur yang valid', () {
    s.login('warga@demo.id', '123456');
    expect(
      s.addReport(
        category: 'Pohon tumbang',
        description: 'Pohon menutup jalan gang',
        location: 'Gang 2',
        lat: -6.8870,
        lng: 107.5920,
      ),
      isNull,
    );
    final id = s.myReports.first.id;
    s.logout();

    s.login('rt@demo.id', '123456');
    final r = s.reportById(id)!;
    // Tidak bisa langsung selesai, dan tolak wajib beralasan.
    s.setStatus(r, ReportStatus.selesai);
    expect(r.status, ReportStatus.menunggu);
    s.setStatus(r, ReportStatus.ditolak, reason: '   ');
    expect(r.status, ReportStatus.menunggu);

    s.setStatus(r, ReportStatus.terverifikasi, severity: Severity.waspada);
    expect(r.status, ReportStatus.terverifikasi);
    // Tidak bisa diverifikasi dua kali / ditolak setelah diverifikasi.
    s.setStatus(r, ReportStatus.ditolak, reason: 'salah');
    expect(r.status, ReportStatus.terverifikasi);
    s.setStatus(r, ReportStatus.selesai);
    expect(r.status, ReportStatus.selesai);
  });

  test('Notifikasi sampai ke penulis laporan dan warga sekitar', () {
    s.login('warga@demo.id', '123456');
    s.addReport(
      category: 'Banjir',
      description: 'Air mulai naik di depan masjid',
      location: 'Depan masjid',
      lat: -6.8870,
      lng: 107.5920,
    );
    final id = s.myReports.first.id;
    s.logout();

    s.login('rt@demo.id', '123456');
    // Pengurus mendapat kabar laporan baru.
    expect(s.myNotifications.any((n) => n.title.startsWith('Laporan baru')),
        isTrue);
    s.setStatus(s.reportById(id)!, ReportStatus.terverifikasi,
        severity: Severity.waspada);
    s.logout();

    s.login('warga@demo.id', '123456');
    expect(s.myNotifications.any((n) => n.title == 'Laporan diverifikasi'),
        isTrue);
    s.logout();

    s.login('admin@demo.id', '123456'); // satu kelurahan, bukan pelapor
    expect(
      s.myNotifications.any((n) =>
          n.kind == 'alert' &&
          n.title == 'Waspada: Banjir di sekitar Anda' &&
          n.body.contains('Depan masjid')),
      isTrue,
    );
  });

  test('Peringatan tidak dikirim ke warga yang menonaktifkannya', () {
    s.login('admin@demo.id', '123456');
    s.setAlerts(false);
    s.logout();

    // Ketua RT membuat dan memverifikasi laporan baru (sendiri).
    s.login('rt@demo.id', '123456');
    expect(
      s.addReport(
        category: 'Kebakaran',
        description: 'Api terlihat dari dapur rumah tetangga',
        location: 'Dapur tetangga',
        lat: -6.8870,
        lng: 107.5920,
      ),
      isNull,
    );
    final r = s.myReports.first;
    s.setStatus(r, ReportStatus.terverifikasi, severity: Severity.bahaya);
    s.logout();

    bool gotAlert() => s.myNotifications.any((n) =>
        n.kind == 'alert' &&
        n.title == 'Bahaya: Kebakaran di sekitar Anda' &&
        n.body.contains('Dapur tetangga'));

    s.login('admin@demo.id', '123456');
    expect(gotAlert(), isFalse); // admin menonaktifkan peringatan
    s.setAlerts(true);
    s.logout();

    s.login('warga@demo.id', '123456');
    expect(gotAlert(), isTrue); // warga yang mengaktifkan tetap menerima
  });

  test('SOS terpisah per akun, bisa dibatalkan dengan alasan', () {
    s.login('warga@demo.id', '123456');
    final e = s.triggerSos(lat: -6.8868, lng: 107.5919);
    expect(e.lat, closeTo(-6.8868, 1e-9));
    expect(s.activeSos, same(e));
    expect(s.triggerSos(), same(e)); // tidak membuat SOS ganda
    s.logout();

    // Pengurus menerima SOS, tetapi SOS itu bukan miliknya.
    s.login('rt@demo.id', '123456');
    expect(s.activeSos, isNull);
    expect(s.sosHistory, isEmpty);
    expect(s.myNotifications.any((n) => n.kind == 'sos'), isTrue);
    s.logout();

    s.login('warga@demo.id', '123456');
    s.cancelSos('Salah pencet');
    expect(s.activeSos, isNull);
    expect(s.sosHistory.first.cancelReason, 'Salah pencet');
    expect(s.sosHistory.first.statusLabel, contains('Dibatalkan'));
  });

  test('Cakupan laporan menyesuaikan tingkat wilayah pengguna', () {
    s.login('warga@demo.id', '123456');
    expect(s.availableScopes, ReportScope.values); // RT -> semua cakupan
    s.logout();

    s.login('admin@demo.id', '123456'); // admin tingkat kelurahan
    expect(s.availableScopes.contains(ReportScope.rt), isFalse);
    expect(s.availableScopes.contains(ReportScope.kelurahan), isTrue);
  });

  test('Ketua RT tidak bisa mengelola pengumuman di luar wilayahnya', () {
    s.login('rt@demo.id', '123456');
    final kota = s.announcements.firstWhere((a) => a.id == 'a1'); // tingkat kota
    final rt = s.announcements.firstWhere((a) => a.id == 'a2'); // RT 03
    expect(s.canManageAnnouncement(kota), isFalse);
    expect(s.canManageAnnouncement(rt), isTrue);

    final pinned = kota.pinned;
    s.togglePin(kota);
    expect(kota.pinned, pinned);
    s.togglePin(rt);
    expect(rt.pinned, isTrue);
  });

  // ------------------------------------------------ peran dan persetujuan

  test('Pendaftaran Ketua RT menunggu persetujuan dan tidak bisa memverifikasi',
      () {
    final u = AppUser(
      name: 'Calon RT',
      email: 'calon@demo.id',
      phone: '0812-0000-1212',
      password: '123456',
      role: UserRole.ketuaRt,
      areaId: RegionIds.rtSukagalih0601,
    );
    expect(s.register(u), isNull);
    expect(u.status, AccountStatus.menunggu);
    expect(u.approved, isFalse);

    // Admin kelurahan menyetujui; sesudahnya akun aktif.
    s.login('admin@demo.id', '123456');
    expect(s.pendingApprovals.any((x) => x.email == u.email), isTrue);
    s.approve(u);
    expect(u.status, AccountStatus.aktif);
  });

  test('Penolakan akun wajib beralasan dan diberitahukan ke pendaftar', () {
    s.login('admin@demo.id', '123456');
    final joni = s.userByEmail('joni@demo.id')!;
    expect(s.rejectAccount(joni, '  '), isNotNull);
    expect(joni.status, AccountStatus.menunggu);
    expect(s.rejectAccount(joni, 'Data tidak lengkap'), isNull);
    expect(joni.status, AccountStatus.ditolak);
    expect(joni.statusNote, 'Data tidak lengkap');
    // Tidak bisa ditolak dua kali.
    expect(s.rejectAccount(joni, 'lagi'), isNotNull);
  });

  test('Ketua RT hanya menyetujui relawan di RT-nya', () {
    s.login('rt@demo.id', '123456');
    final tono = s.userByEmail('tono@demo.id')!; // relawan RT 03
    final sari = s.userByEmail('sari@demo.id')!; // Ketua RT 04
    expect(s.canApprove(s.me, tono), isTrue);
    expect(s.canApprove(s.me, sari), isFalse);
    s.approve(sari);
    expect(sari.status, AccountStatus.menunggu);
    s.approve(tono);
    expect(tono.status, AccountStatus.aktif);
  });

  test('Warga tidak bisa menyetujui akun', () {
    s.login('warga@demo.id', '123456');
    expect(s.pendingApprovals, isEmpty);
    final tono = s.userByEmail('tono@demo.id')!;
    s.approve(tono);
    expect(tono.status, AccountStatus.menunggu);
  });

  // ---------------------------------------------------------- Super Admin

  test('Super Admin membuat dan mengubah akun beserta wilayahnya', () {
    s.login('super@demo.id', '123456');
    expect(
      s.createAccount(
        name: 'Petugas Baru',
        email: 'baru@demo.id',
        phone: '0812-0000-3434',
        password: '123456',
        role: UserRole.petugas,
        areaId: RegionIds.rtPasteur0201,
      ),
      isNull,
    );
    final u = s.userByEmail('baru@demo.id')!;
    expect(u.status, AccountStatus.aktif);

    // Validasi.
    expect(
        s.createAccount(
            name: 'X',
            email: 'baru@demo.id',
            phone: '',
            password: '123456',
            role: UserRole.warga,
            areaId: RegionIds.rtPasteur0201),
        contains('sudah terdaftar'));
    expect(
        s.createAccount(
            name: 'X',
            email: 'bukan-email',
            phone: '',
            password: '123456',
            role: UserRole.warga,
            areaId: RegionIds.rtPasteur0201),
        isNotNull);
    expect(
        s.createAccount(
            name: 'X',
            email: 'x@demo.id',
            phone: '',
            password: '123',
            role: UserRole.warga,
            areaId: RegionIds.rtPasteur0201),
        contains('minimal 6'));

    // Ubah wilayah kewenangan tanpa mengubah kode.
    expect(s.updateAccount(u, areaId: RegionIds.rtSukagalih0503), isNull);
    expect(u.areaId, RegionIds.rtSukagalih0503);
    // Admin wajib tingkat kelurahan ke atas.
    expect(
        s.updateAccount(u,
            role: UserRole.admin, areaId: RegionIds.rtSukagalih0503),
        isNotNull);
    expect(
        s.updateAccount(u,
            role: UserRole.admin, areaId: RegionIds.kelPasteur),
        isNull);
    // Peran sendiri tidak boleh diturunkan.
    expect(s.updateAccount(s.me, role: UserRole.warga), isNotNull);
  });

  test('Selain Super Admin tidak boleh mengelola akun', () {
    s.login('admin@demo.id', '123456');
    expect(
      s.createAccount(
        name: 'X',
        email: 'x@demo.id',
        phone: '',
        password: '123456',
        role: UserRole.warga,
        areaId: RegionIds.rtSukagalih0503,
      ),
      isNotNull,
    );
    expect(s.updateAccount(s.userByEmail('warga@demo.id')!, name: 'Z'),
        isNotNull);
  });

  test('Admin hanya menambah RW/RT di wilayahnya', () {
    s.login('admin@demo.id', '123456');
    expect(s.addLocalRegion(RegionIds.kelSukagalih, '8'), isNotNull);
    expect(s.addLocalRegion(RegionIds.kelPasteur, '8'), isNull);
    s.logout();
    s.login('warga@demo.id', '123456');
    expect(s.addLocalRegion(RegionIds.kelSukagalih, '7'), isNull);
  });

  // ----------------------------------------------------- SOS dan siaran

  test('Petugas menanggapi SOS di wilayahnya, satu kali saja', () {
    s.login('warga@demo.id', '123456');
    final e = s.triggerSos(lat: -6.8868, lng: 107.5919);
    s.logout();

    s.login('petugas@demo.id', '123456');
    expect(s.respondSos(e), isNull);
    expect(e.respondedBy, contains('Petugas Dani'));
    expect(s.respondSos(e), isNotNull); // sudah ditanggapi
    s.logout();

    s.login('warga@demo.id', '123456');
    expect(s.myNotifications.any((n) => n.title == 'SOS Anda ditanggapi'),
        isTrue);
  });

  test('Warga biasa tidak bisa menanggapi SOS', () {
    s.login('warga@demo.id', '123456');
    final e = s.triggerSos();
    expect(s.respondSos(e), isNotNull);
    expect(e.respondedBy, isNull);
  });

  test('Siaran darurat: hak kirim, penerima, alarm, dan konfirmasi', () {
    s.login('warga@demo.id', '123456');
    expect(
      s.sendBroadcast(
              title: 'Tes', message: 'Pesan uji', severity: Severity.bahaya)
          .success,
      isFalse,
    );
    s.logout();

    s.login('admin@demo.id', '123456');
    final bad = s.sendBroadcast(
        title: '', message: 'Pesan uji', severity: Severity.bahaya);
    expect(bad.success, isFalse);
    final res = s.sendBroadcast(
      title: 'Banjir bandang',
      message: 'Segera menuju posko evakuasi terdekat.',
      severity: Severity.bahaya,
    );
    expect(res.success, isTrue);
    final b = res.broadcast!;
    expect(b.recipients, greaterThan(0));
    expect(b.deliveredTo.contains('admin@demo.id'), isFalse);
    expect(s.sentBroadcasts.first.id, b.id);
    s.logout();

    s.login('warga@demo.id', '123456');
    expect(s.pendingAlarm?.id, b.id);
    expect(
        s.myNotifications.any((n) => n.kind == 'broadcast'), isTrue);
    s.acknowledgeAlarm(b.id);
    expect(s.pendingAlarm, isNull);
    expect(b.acknowledged, 1);
  });

  test('Siaran berradius hanya menjangkau pengguna di dalam radius', () {
    s.login('warga@demo.id', '123456');
    s.updateMyLocation(-6.8868, 107.5919);
    s.logout();

    s.login('petugas@demo.id', '123456');
    final jauh = s.sendBroadcast(
      title: 'Jauh',
      message: 'Radius di Jakarta',
      severity: Severity.waspada,
      areaId: RegionIds.kelSukagalih,
      lat: -6.2268,
      lng: 106.8,
      radiusM: 500,
    );
    expect(jauh.broadcast!.deliveredTo.contains('warga@demo.id'), isFalse);

    final dekat = s.sendBroadcast(
      title: 'Dekat',
      message: 'Radius di sekitar warga',
      severity: Severity.waspada,
      areaId: RegionIds.kelSukagalih,
      lat: -6.8868,
      lng: 107.5919,
      radiusM: 500,
    );
    expect(dekat.broadcast!.deliveredTo.contains('warga@demo.id'), isTrue);

    // Radius tanpa titik pusat ditolak.
    expect(
      s.sendBroadcast(
              title: 'X',
              message: 'Tanpa pusat',
              severity: Severity.info,
              radiusM: 500)
          .success,
      isFalse,
    );
  });

  test('Admin tidak bisa menyiarkan ke luar wilayah kewenangannya', () {
    s.login('admin@demo.id', '123456');
    final r = s.sendBroadcast(
      title: 'Luar',
      message: 'Wilayah lain',
      severity: Severity.info,
      areaId: RegionIds.kelPasteur,
    );
    expect(r.success, isFalse);
  });

  // ----------------------------------------------- keselamatan dan posko

  test('Status "Butuh bantuan" membuat permintaan bantuan dan memberi tahu pengurus',
      () {
    s.login('warga@demo.id', '123456');
    final me = s.myFamily.firstWhere((m) => m.relation == 'Saya');
    final before = s.helpRequests.length;
    s.setSafety(me, SafetyStatus.butuhBantuan);
    expect(me.status, SafetyStatus.butuhBantuan);
    expect(s.helpRequests.length, before + 1);
    // Mengulang status yang sama tidak menggandakan permintaan.
    s.setSafety(me, SafetyStatus.butuhBantuan);
    expect(s.helpRequests.length, before + 1);
    s.logout();

    s.login('rt@demo.id', '123456');
    expect(s.myNotifications.any((n) => n.title.startsWith('Butuh bantuan')),
        isTrue);
  });

  test('Relawan memperbarui hunian posko; penuh memicu status Penuh', () {
    s.login('relawan@demo.id', '123456');
    final p = s.evacuationPoints.firstWhere((e) => e.id == 'e2');
    expect(s.setOccupants(p, -1), isNotNull);
    expect(s.setOccupants(p, p.capacity), isNull);
    expect(p.state, PoskoState.penuh);
    s.logout();

    // Warga tidak berwenang.
    s.login('warga@demo.id', '123456');
    expect(s.setOccupants(p, 0), isNotNull);
    expect(p.occupants, p.capacity);
  });

  // ------------------------------------------------------------- push

  test('Payload FCM dibaca sesuai kontrak dan bukan-siaran diabaikan', () {
    expect(PushBroadcast.fromData({'type': 'lain'}), isNull);
    final b = PushBroadcast.fromData({
      'type': 'emergency_broadcast',
      'id': 'bc-1',
      'title': 'Banjir',
      'message': 'Evakuasi',
      'severity': 'waspada',
      'areaId': RegionIds.kelSukagalih,
      'lat': '-6.8868',
      'lng': '107.5919',
      'radiusM': '1500',
    })!;
    expect(b.severity, Severity.waspada);
    expect(b.radiusM, 1500);
    expect(b.lat, closeTo(-6.8868, 1e-9));
  });

  test('Siaran push diterima di wilayah yang sama, sekali saja', () {
    s.login('warga@demo.id', '123456');
    PushBroadcast make(String area, {String id = 'bc-9'}) => PushBroadcast(
        id: id, title: 'Banjir', message: 'Evakuasi', severity: Severity.bahaya,
        areaId: area);

    // Wilayah lain ditolak.
    expect(s.receiveRemoteBroadcast(make(RegionIds.kelPasteur)), isFalse);
    expect(s.pendingAlarm, isNull);

    expect(s.receiveRemoteBroadcast(make(RegionIds.kelSukagalih)), isTrue);
    expect(s.pendingAlarm?.id, 'bc-9');
    // Duplikat (id sama) tidak membunyikan alarm lagi.
    s.acknowledgeAlarm('bc-9');
    expect(s.receiveRemoteBroadcast(make(RegionIds.kelSukagalih)), isFalse);
    expect(s.pendingAlarm, isNull);
  });
}
