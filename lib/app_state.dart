import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'config.dart';
import 'data/regions.dart';
import 'data/seed.dart';
import 'geo.dart';
import 'models.dart';
import 'safety_models.dart';
import 'services/push_service.dart';

part 'app_state_accounts.dart';
part 'app_state_reports.dart';
part 'app_state_alerts.dart';
part 'app_state_safety.dart';

class _ResetCode {
  final String code;
  final DateTime expires;
  _ResetCode(this.code, this.expires);
}

/// Status darurat wilayah (kelurahan pengguna) untuk banner beranda.
enum RegionStatus { aman, siaga, darurat }

extension RegionStatusX on RegionStatus {
  String get label => switch (this) {
        RegionStatus.aman => 'Aman',
        RegionStatus.siaga => 'Siaga',
        RegionStatus.darurat => 'Darurat',
      };
}

/// State aplikasi (versi awal, di memori). Pada versi lengkap, data ini
/// berasal dari REST API dan disimpan lokal (Drift/SQLite) untuk mode offline.
///
/// Logika dipecah per bidang lewat berkas `part`:
///  - app_state_accounts.dart : hak akses, persetujuan akun, Super Admin
///  - app_state_reports.dart  : laporan, riwayat, tugas petugas
///  - app_state_alerts.dart   : SOS, siaran darurat, notifikasi, pengumuman
///  - app_state_safety.dart   : keluarga, orang hilang, posko, logistik, relawan
class AppState extends ChangeNotifier {
  AppState._() {
    _seed();
  }
  static final AppState instance = AppState._();

  /// Laporan baru dianggap valid otomatis bila dikonfirmasi sebanyak ini
  /// oleh warga berbeda di kelurahan yang sama (cadangan bila Ketua RT belum
  /// sempat memverifikasi).
  static const int autoVerifyThreshold = 3;

  /// Batas laporan per pengguna per jam (anti-spam).
  static const int maxReportsPerHour = 5;

  /// Pembatasan percobaan login (anti tebak sandi).
  static const int maxLoginAttempts = 5;
  static const Duration loginLockDuration = Duration(seconds: 30);

  /// Masa berlaku kode reset kata sandi.
  static const Duration resetCodeTtl = Duration(minutes: 10);

  /// Laporan sejenis di dekat titik yang sama dalam rentang ini dianggap
  /// mungkin ganda.
  static const Duration duplicateWindow = Duration(hours: 6);

  /// Batas jumlah anggota keluarga per akun.
  static const int maxFamilyMembers = 12;

  final List<AppUser> users = [];
  final List<Report> reports = [];
  final List<Announcement> announcements = [];
  final List<EvacuationPoint> evacuationPoints = [];
  final List<SosEvent> sosEvents = [];
  final List<EmergencyBroadcast> broadcasts = [];
  final List<MissingPerson> missingPersons = [];
  final List<HelpRequest> helpRequests = [];
  final List<LocalContact> localContacts = [];

  final Map<String, List<EmergencyContact>> _contacts = {};
  final Map<String, List<AppNotification>> _notifs = {};
  final Map<String, List<FamilyMember>> _family = {};

  /// Siaran darurat yang belum ditampilkan sebagai alarm, per email penerima.
  final Map<String, List<String>> _pendingAlarms = {};
  final Map<String, int> _failedLogins = {};
  final Map<String, DateTime> _lockedUntil = {};
  final Map<String, _ResetCode> _resetCodes = {};
  final Random _rnd = Random();

  AppUser? currentUser;

  bool largeFont = false;
  bool offline = false;

  bool get loggedIn => currentUser != null;
  AppUser get me => currentUser!;
  int _idSeq = 100;
  String _newId(String p) => '$p${_idSeq++}';

  // Pengaturan peringatan disimpan pada akun masing-masing.
  bool get alertsEnabled => currentUser?.alertsEnabled ?? true;
  double get alertRadiusM => currentUser?.alertRadiusM ?? 500;

  /// Memberi tahu pendengar. Dipakai berkas `part` (notifyListeners bersifat
  /// protected sehingga tidak boleh dipanggil langsung dari extension).
  void _changed() => notifyListeners();

  void _seed() {
    users.addAll(buildSeedUsers());
    reports.addAll(buildSeedReports());
    announcements.addAll(buildSeedAnnouncements());
    evacuationPoints.addAll(buildSeedEvacuation());
    missingPersons.addAll(buildSeedMissing());
    helpRequests.addAll(buildSeedHelpRequests());
    localContacts.addAll(buildSeedLocalContacts());
    _family.addAll(buildSeedFamilies());
  }

  /// Mengembalikan semua data ke kondisi awal (dipakai tes).
  void resetForTests() {
    users.clear();
    reports.clear();
    announcements.clear();
    evacuationPoints.clear();
    sosEvents.clear();
    broadcasts.clear();
    missingPersons.clear();
    helpRequests.clear();
    localContacts.clear();
    _contacts.clear();
    _notifs.clear();
    _family.clear();
    _pendingAlarms.clear();
    _failedLogins.clear();
    _lockedUntil.clear();
    _resetCodes.clear();
    currentUser = null;
    largeFont = false;
    offline = false;
    Regions.resetToSeed();
    _seed();
    notifyListeners();
  }

  // ---------------------------------------------------------------- akun

  AppUser? userByEmail(String email) {
    final e = email.trim().toLowerCase();
    for (final u in users) {
      if (u.email == e) return u;
    }
    return null;
  }

  String? login(String email, String password) {
    final e = email.trim().toLowerCase();
    final now = DateTime.now();
    final lock = _lockedUntil[e];
    if (lock != null) {
      if (now.isBefore(lock)) {
        final secs = lock.difference(now).inSeconds + 1;
        return 'Terlalu banyak percobaan. Coba lagi dalam $secs detik.';
      }
      _lockedUntil.remove(e);
    }
    final found = userByEmail(e);
    if (found == null || found.password != password) {
      final n = (_failedLogins[e] ?? 0) + 1;
      if (n >= maxLoginAttempts) {
        _failedLogins.remove(e);
        _lockedUntil[e] = now.add(loginLockDuration);
        return 'Terlalu banyak percobaan. Akun dikunci '
            '${loginLockDuration.inSeconds} detik.';
      }
      _failedLogins[e] = n;
      return 'Email atau kata sandi salah';
    }
    // Sandi benar; akun yang ditolak atau dinonaktifkan tidak boleh masuk.
    if (found.status == AccountStatus.ditolak) {
      return 'Pendaftaran akun ditolak. Alasan: ${found.statusNote ?? '-'}';
    }
    if (found.status == AccountStatus.dinonaktifkan) {
      return 'Akun dinonaktifkan oleh administrator. '
          'Alasan: ${found.statusNote ?? '-'}';
    }
    _failedLogins.remove(e);
    currentUser = found;
    _syncPush();
    notifyListeners();
    return null;
  }

  /// Mendaftar akun baru. Warga langsung aktif; Ketua RT, Petugas Lapangan,
  /// dan Relawan menunggu persetujuan. Admin Wilayah/Super Admin tidak bisa
  /// mendaftar sendiri (dibuat oleh Super Admin).
  String? register(AppUser user) {
    if (userByEmail(user.email) != null) return 'Email sudah terdaftar';
    if (!user.role.selfRegisterable) {
      return 'Peran ${user.role.label} dibuat oleh Super Admin.';
    }
    final areaError = areaErrorFor(user.role, user.areaId);
    if (areaError != null) return areaError;
    user.status =
        user.role.needsApproval ? AccountStatus.menunggu : AccountStatus.aktif;
    users.add(user);
    if (user.status == AccountStatus.menunggu) _notifyApprovers(user);
    currentUser = user;
    _syncPush();
    notifyListeners();
    return null;
  }

  void logout() {
    currentUser = null;
    _syncPush();
    notifyListeners();
  }

  /// Berlangganan topik FCM sesuai wilayah pengguna (tidak berbuat apa-apa
  /// bila FCM belum dikonfigurasi).
  void _syncPush() {
    if (!AppConfig.pushEnabled) return;
    unawaited(PushService.instance.syncTopics(currentUser?.areaId));
  }

  /// Simulasi pengiriman kode reset lewat email. Mengembalikan kode (untuk
  /// ditampilkan di layar demo) atau null bila email tidak terdaftar.
  /// Versi lengkap: server mengirim tautan/kode ke email, bukan ke layar.
  String? requestPasswordReset(String email) {
    final u = userByEmail(email);
    if (u == null) return null;
    final code = (100000 + _rnd.nextInt(900000)).toString();
    _resetCodes[u.email] = _ResetCode(code, DateTime.now().add(resetCodeTtl));
    return code;
  }

  /// Mengembalikan pesan error, atau null bila kata sandi berhasil diganti.
  String? confirmPasswordReset(String email, String code, String newPassword) {
    final u = userByEmail(email);
    final entry = u == null ? null : _resetCodes[u.email];
    if (u == null || entry == null) return 'Minta kode reset terlebih dahulu';
    if (DateTime.now().isAfter(entry.expires)) {
      _resetCodes.remove(u.email);
      return 'Kode sudah kedaluwarsa. Minta kode baru.';
    }
    if (entry.code != code.trim()) return 'Kode salah';
    if (newPassword.length < 6) return 'Kata sandi minimal 6 karakter';
    u.password = newPassword;
    _resetCodes.remove(u.email);
    _failedLogins.remove(u.email);
    _lockedUntil.remove(u.email);
    notifyListeners();
    return null;
  }

  /// Pindah wilayah (RT baru). Peran yang butuh persetujuan harus disetujui
  /// ulang oleh pengurus wilayah yang baru.
  String? changeArea(String rtId) {
    final u = currentUser;
    if (u == null) return 'Silakan masuk terlebih dahulu';
    if (u.role == UserRole.admin || u.role == UserRole.superAdmin) {
      return 'Wilayah ${u.role.label} diatur oleh Super Admin.';
    }
    final err = areaErrorFor(u.role, rtId);
    if (err != null) return err;
    u.areaId = rtId;
    if (u.role.needsApproval) {
      u.status = AccountStatus.menunggu;
      _notifyApprovers(u);
    }
    _syncPush();
    notifyListeners();
    return null;
  }

  // ------------------------------------------------------- notifikasi

  List<AppNotification> _notifsFor(String email) => _notifs.putIfAbsent(
        email,
        () => [
          AppNotification(
            id: 'n-welcome',
            title: 'Selamat datang di Warga Siaga',
            body: 'Atur radius peringatan dan kontak darurat di menu Akun.',
            kind: 'info',
            createdAt: DateTime.now(),
          ),
        ],
      );

  void _notify(
    AppUser to,
    String title,
    String body,
    String kind, {
    String? broadcastId,
  }) {
    _notifsFor(to.email).insert(
      0,
      AppNotification(
        id: _newId('n'),
        title: title,
        body: body,
        kind: kind,
        createdAt: DateTime.now(),
        broadcastId: broadcastId,
      ),
    );
  }

  List<AppNotification> get myNotifications => _notifsFor(me.email);

  int get unreadCount => myNotifications.where((n) => !n.read).length;

  void markAllRead() {
    for (final n in myNotifications) {
      n.read = true;
    }
    notifyListeners();
  }

  // ------------------------------------------------------- lokasi

  /// Menyimpan lokasi terakhir pengguna (dari GPS).
  void updateMyLocation(double lat, double lng) {
    final u = currentUser;
    if (u == null || !isValidCoord(lat, lng)) return;
    u.lastLat = lat;
    u.lastLng = lng;
    u.lastLocationAt = DateTime.now();
  }

  /// Titik acuan pengguna: lokasi GPS terakhir, atau pusat kelurahan.
  GeoPoint? get myReferencePoint {
    final u = currentUser;
    if (u == null) return null;
    if (u.hasLocation) return GeoPoint(u.lastLat!, u.lastLng!);
    return Regions.centroid(u.areaId);
  }

  // ------------------------------------------------------- status wilayah

  /// Status darurat kelurahan pengguna: darurat bila ada laporan Bahaya yang
  /// aktif dan terverifikasi atau siaran darurat Bahaya dalam 6 jam terakhir;
  /// siaga bila ada laporan Waspada yang aktif dan terverifikasi.
  RegionStatus get regionStatus {
    final u = currentUser;
    if (u == null) return RegionStatus.aman;
    final kel = Regions.ancestorAtLevel(u.areaId, RegionLevel.kelurahan);
    final scope = kel ?? u.areaId;
    var level = RegionStatus.aman;
    for (final r in reports) {
      final live = r.status == ReportStatus.terverifikasi ||
          r.status == ReportStatus.diproses;
      if (!live || !Regions.isWithin(r.areaId, scope)) continue;
      if (r.severity == Severity.bahaya) return RegionStatus.darurat;
      if (r.severity == Severity.waspada) level = RegionStatus.siaga;
    }
    final since = DateTime.now().subtract(const Duration(hours: 6));
    for (final b in broadcasts) {
      if (b.createdAt.isAfter(since) &&
          b.severity == Severity.bahaya &&
          Regions.isWithin(u.areaId, b.areaId)) {
        return RegionStatus.darurat;
      }
    }
    return level;
  }

  // ------------------------------------------------------- pengaturan

  void setLargeFont(bool v) {
    largeFont = v;
    notifyListeners();
  }

  void setAlerts(bool v) {
    currentUser?.alertsEnabled = v;
    notifyListeners();
  }

  void setRadius(double v) {
    currentUser?.alertRadiusM = v;
    notifyListeners();
  }

  /// Perkiraan jumlah warga dalam radius (simulasi; versi lengkap memakai
  /// query PostGIS ST_DWithin pada tabel lokasi pengguna).
  int estimateRecipients(String areaId, double radiusM) {
    final seed = areaId.codeUnits.fold<int>(0, (a, b) => a + b) % 20;
    return (radiusM / 12).round() + seed;
  }

  // ------------------------------------------------------- offline

  /// Sinkronisasi laporan yang dibuat saat offline.
  int syncPending() {
    final u = currentUser;
    if (u == null) return 0;
    var n = 0;
    for (final r in myReports) {
      if (r.pendingSync) {
        r.pendingSync = false;
        n++;
        _markSynced(r);
      }
    }
    if (n > 0) {
      _notify(
        u,
        'Sinkronisasi selesai',
        '$n laporan offline berhasil dikirim ke server.',
        'info',
      );
    }
    return n;
  }

  int get pendingCount => myReports.where((r) => r.pendingSync).length;

  /// Mengembalikan jumlah laporan yang tersinkron saat kembali online.
  int setOffline(bool v) {
    offline = v;
    final synced = v ? 0 : syncPending();
    notifyListeners();
    return synced;
  }
}
