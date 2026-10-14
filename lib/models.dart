import 'package:flutter/material.dart';
import 'geo.dart';

enum Severity { info, waspada, bahaya }

extension SeverityX on Severity {
  String get label => switch (this) {
        Severity.info => 'Info',
        Severity.waspada => 'Waspada',
        Severity.bahaya => 'Bahaya',
      };
}

/// Alur status laporan:
/// menunggu -> terverifikasi -> diproses -> selesai, atau menunggu -> ditolak.
/// ("terverifikasi" boleh langsung ke "selesai" untuk masalah ringan.)
enum ReportStatus { menunggu, terverifikasi, diproses, selesai, ditolak }

extension ReportStatusX on ReportStatus {
  String get label => switch (this) {
        ReportStatus.menunggu => 'Menunggu verifikasi',
        ReportStatus.terverifikasi => 'Terverifikasi',
        ReportStatus.diproses => 'Diproses',
        ReportStatus.selesai => 'Selesai',
        ReportStatus.ditolak => 'Ditolak',
      };

  /// Label pendek untuk chip filter.
  String get shortLabel => switch (this) {
        ReportStatus.menunggu => 'Menunggu',
        _ => label,
      };

  /// Laporan yang masih berjalan (belum selesai/ditolak).
  bool get isActive =>
      this == ReportStatus.menunggu ||
      this == ReportStatus.terverifikasi ||
      this == ReportStatus.diproses;
}

/// Tingkat wilayah, dari yang terluas sampai yang terkecil.
enum RegionLevel { provinsi, kota, kecamatan, kelurahan, rw, rt }

extension RegionLevelX on RegionLevel {
  String get label => switch (this) {
        RegionLevel.provinsi => 'Provinsi',
        RegionLevel.kota => 'Kota/Kabupaten',
        RegionLevel.kecamatan => 'Kecamatan',
        RegionLevel.kelurahan => 'Kelurahan/Desa',
        RegionLevel.rw => 'RW',
        RegionLevel.rt => 'RT',
      };
}

/// Peran pengguna.
///  - warga: melapor, melihat status darurat, memantau wilayah.
///  - ketuaRt: memverifikasi laporan di RT-nya.
///  - petugas: petugas lapangan; menerima tugas, mengubah status penanganan.
///  - relawan: membantu evakuasi, logistik, koordinasi.
///  - admin: admin wilayah/instansi (kelurahan/kecamatan/kota).
///  - superAdmin: mengelola seluruh akun dan hak akses wilayah.
enum UserRole { warga, ketuaRt, petugas, relawan, admin, superAdmin }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.warga => 'Warga',
        UserRole.ketuaRt => 'Ketua RT',
        UserRole.petugas => 'Petugas Lapangan',
        UserRole.relawan => 'Relawan',
        UserRole.admin => 'Admin Wilayah',
        UserRole.superAdmin => 'Super Admin',
      };

  String get description => switch (this) {
        UserRole.warga =>
          'Melaporkan kejadian, melihat status darurat, dan memantau wilayah.',
        UserRole.ketuaRt =>
          'Memverifikasi laporan warga di tingkat RT dan memantau kondisi sekitar.',
        UserRole.petugas =>
          'Menerima tugas operasional, mengubah status penanganan, dan melaporkan kondisi lapangan.',
        UserRole.relawan =>
          'Membantu evakuasi, logistik, dan koordinasi darurat.',
        UserRole.admin =>
          'Mengawasi wilayah administratif tertentu (kelurahan/kecamatan).',
        UserRole.superAdmin =>
          'Mengelola seluruh akun dan hak akses wilayah.',
      };

  /// Peran yang wajib disetujui sebelum aktif penuh.
  bool get needsApproval =>
      this == UserRole.ketuaRt ||
      this == UserRole.petugas ||
      this == UserRole.relawan;

  /// Peran yang boleh dipilih saat mendaftar sendiri.
  bool get selfRegisterable =>
      this != UserRole.admin && this != UserRole.superAdmin;
}

/// Status akun. Akun yang menunggu persetujuan boleh masuk tetapi hanya
/// memiliki hak seperti warga sampai disetujui.
enum AccountStatus { aktif, menunggu, ditolak, dinonaktifkan }

extension AccountStatusX on AccountStatus {
  String get label => switch (this) {
        AccountStatus.aktif => 'Aktif',
        AccountStatus.menunggu => 'Menunggu persetujuan',
        AccountStatus.ditolak => 'Ditolak',
        AccountStatus.dinonaktifkan => 'Dinonaktifkan',
      };
}

/// Cakupan tampilan data: seberapa luas laporan yang ingin dilihat.
enum ReportScope { rt, rw, kelurahan, kecamatan, kota }

extension ReportScopeX on ReportScope {
  String get label => switch (this) {
        ReportScope.rt => 'RT',
        ReportScope.rw => 'RW',
        ReportScope.kelurahan => 'Kelurahan',
        ReportScope.kecamatan => 'Kecamatan',
        ReportScope.kota => 'Kota',
      };

  RegionLevel get level => switch (this) {
        ReportScope.rt => RegionLevel.rt,
        ReportScope.rw => RegionLevel.rw,
        ReportScope.kelurahan => RegionLevel.kelurahan,
        ReportScope.kecamatan => RegionLevel.kecamatan,
        ReportScope.kota => RegionLevel.kota,
      };
}

class Region {
  final String id;
  final String name;
  final RegionLevel level;
  final String? parentId;
  const Region(this.id, this.name, this.level, this.parentId);
}

class AppUser {
  String name;
  final String email;
  String phone;
  String password;
  UserRole role;

  /// Wilayah akun. Warga/Ketua RT/Petugas/Relawan: RT tempat tinggal.
  /// Admin Wilayah: wilayah yang diawasi (kelurahan/kecamatan/kota), diatur
  /// Super Admin. Super Admin: tidak dibatasi wilayah.
  String areaId;

  AccountStatus status;

  /// Alasan penolakan atau penonaktifan (ditampilkan ke pemilik akun).
  String? statusNote;

  final DateTime createdAt;

  /// Pengaturan peringatan disimpan per akun, bukan global, supaya notifikasi
  /// hanya dikirim ke pengguna yang mengaktifkannya.
  bool alertsEnabled;
  double alertRadiusM;

  /// Lokasi terakhir yang diketahui (dari GPS), dipakai untuk menyaring
  /// siaran darurat berdasarkan radius.
  double? lastLat;
  double? lastLng;
  DateTime? lastLocationAt;

  AppUser({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
    required this.areaId,
    this.status = AccountStatus.aktif,
    this.statusNote,
    DateTime? createdAt,
    this.alertsEnabled = true,
    this.alertRadiusM = 500,
    this.lastLat,
    this.lastLng,
    this.lastLocationAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get approved => status == AccountStatus.aktif;

  bool get hasLocation => isValidCoord(lastLat, lastLng);
}

class CategoryInfo {
  final String name;
  final IconData icon;
  final Severity defaultSeverity;
  const CategoryInfo(this.name, this.icon, this.defaultSeverity);
}

const List<CategoryInfo> kCategories = [
  CategoryInfo('Banjir', Icons.water, Severity.waspada),
  CategoryInfo('Longsor', Icons.terrain, Severity.waspada),
  CategoryInfo('Gempa/Kerusakan', Icons.vibration, Severity.waspada),
  CategoryInfo('Kebakaran', Icons.local_fire_department, Severity.bahaya),
  CategoryInfo('Pohon tumbang', Icons.park, Severity.waspada),
  CategoryInfo('Jalan rusak', Icons.construction, Severity.info),
  CategoryInfo('Sampah', Icons.delete_outline, Severity.info),
  CategoryInfo('Lampu mati', Icons.lightbulb_outline, Severity.info),
  CategoryInfo('Lainnya', Icons.report_gmailerrorred, Severity.info),
];

CategoryInfo categoryInfo(String name) {
  for (final c in kCategories) {
    if (c.name == name) return c;
  }
  return kCategories.last;
}

class ReportComment {
  final String author;
  final String text;
  final DateTime createdAt;
  final bool official;

  /// Laporan kondisi riil dari petugas lapangan.
  final bool field;
  const ReportComment({
    required this.author,
    required this.text,
    required this.createdAt,
    this.official = false,
    this.field = false,
  });
}

/// Satu baris riwayat (audit trail) laporan: siapa melakukan apa, kapan.
class TimelineEvent {
  final DateTime at;
  final String actor;
  final String role;
  final String action;

  /// Status laporan setelah aksi ini, bila statusnya berubah.
  final ReportStatus? status;
  final String? note;
  const TimelineEvent({
    required this.at,
    required this.actor,
    required this.role,
    required this.action,
    this.status,
    this.note,
  });
}

class Report {
  final String id;
  final String authorName;
  final String authorEmail;
  final String category;
  final String description;
  final String areaId;
  final String location;
  final DateTime createdAt;
  final bool hasPhoto;

  /// Berkas foto dari kamera perangkat (null untuk data contoh).
  final String? photoPath;

  /// Koordinat dari GPS perangkat. Null bila GPS tidak tersedia.
  final double? lat;
  final double? lng;
  final double? accuracyM;

  Severity severity;
  ReportStatus status;
  int confirmations;
  bool pendingSync;
  String? rejectReason;
  DateTime? verifiedAt;
  DateTime? processedAt;
  DateTime? resolvedAt;

  /// Petugas lapangan yang ditugaskan menangani laporan.
  String? assigneeEmail;
  String? assigneeName;
  DateTime? assignedAt;

  final Set<String> confirmedBy;
  final List<ReportComment> comments;
  final List<TimelineEvent> timeline;

  Report({
    required this.id,
    required this.authorName,
    required this.authorEmail,
    required this.category,
    required this.description,
    required this.areaId,
    required this.location,
    required this.createdAt,
    this.lat,
    this.lng,
    this.accuracyM,
    this.photoPath,
    bool? hasPhoto,
    this.severity = Severity.info,
    this.status = ReportStatus.menunggu,
    this.confirmations = 1,
    this.pendingSync = false,
    this.rejectReason,
    this.verifiedAt,
    this.processedAt,
    this.resolvedAt,
    this.assigneeEmail,
    this.assigneeName,
    this.assignedAt,
    Set<String>? confirmedBy,
    List<ReportComment>? comments,
    List<TimelineEvent>? timeline,
  })  : hasPhoto = hasPhoto ?? photoPath != null,
        confirmedBy = confirmedBy ?? <String>{},
        comments = comments ?? <ReportComment>[],
        timeline = timeline ?? <TimelineEvent>[];

  bool get hasCoordinates => isValidCoord(lat, lng);
}

class Announcement {
  final String id;
  final String areaId;
  final String tag;
  final String title;
  final String body;
  final String author;
  final DateTime createdAt;
  bool pinned;

  Announcement({
    required this.id,
    required this.areaId,
    required this.tag,
    required this.title,
    required this.body,
    required this.author,
    required this.createdAt,
    this.pinned = false,
  });
}

class EmergencyContact {
  final String name;
  final String phone;
  final bool national;
  const EmergencyContact(this.name, this.phone, {this.national = false});
}

/// Barang logistik di sebuah posko.
class LogisticItem {
  final String id;
  final String name;
  final String unit;
  int stock;

  /// Di bawah atau sama dengan angka ini, stok dianggap menipis.
  final int minStock;
  LogisticItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.stock,
    required this.minStock,
  });

  bool get low => stock <= minStock;
}

class LogisticTemplate {
  final String name;
  final String unit;
  final int initial;
  final int minStock;
  const LogisticTemplate(this.name, this.unit, this.initial, this.minStock);
}

/// Jenis logistik darurat yang dipantau di tiap posko.
const List<LogisticTemplate> kLogisticTemplates = [
  LogisticTemplate('Air bersih', 'liter', 500, 100),
  LogisticTemplate('Tenda', 'unit', 10, 2),
  LogisticTemplate('Obat-obatan', 'paket', 20, 5),
  LogisticTemplate('Makanan siap saji', 'paket', 100, 20),
  LogisticTemplate('Selimut', 'lembar', 60, 10),
];

IconData logisticIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('air')) return Icons.water_drop;
  if (n.contains('tenda')) return Icons.holiday_village;
  if (n.contains('obat')) return Icons.medical_services;
  if (n.contains('makan')) return Icons.restaurant;
  if (n.contains('selimut')) return Icons.bed;
  return Icons.inventory_2;
}

enum PoskoState { tersedia, hampirPenuh, penuh, tutup }

extension PoskoStateX on PoskoState {
  String get label => switch (this) {
        PoskoState.tersedia => 'Tersedia',
        PoskoState.hampirPenuh => 'Hampir penuh',
        PoskoState.penuh => 'Penuh',
        PoskoState.tutup => 'Tutup',
      };
}

/// Posko / titik evakuasi beserta daya tampung dan logistiknya.
class EvacuationPoint {
  final String id;
  String name;
  String address;
  final String areaId;
  int capacity;

  /// Jumlah pengungsi yang sedang berada di posko.
  int occupants;
  final double? lat;
  final double? lng;
  bool open;
  String? phone;
  DateTime updatedAt;
  final List<LogisticItem> logistics;

  EvacuationPoint({
    required this.id,
    required this.name,
    required this.address,
    required this.areaId,
    required this.capacity,
    this.occupants = 0,
    this.lat,
    this.lng,
    this.open = true,
    this.phone,
    DateTime? updatedAt,
    List<LogisticItem>? logistics,
  })  : updatedAt = updatedAt ?? DateTime.now(),
        logistics = logistics ?? <LogisticItem>[];

  int get remaining => occupants >= capacity ? 0 : capacity - occupants;

  /// Tingkat keterisian 0.0 - 1.0.
  double get fill {
    if (capacity <= 0) return 1;
    final f = occupants / capacity;
    return f > 1 ? 1 : (f < 0 ? 0 : f);
  }

  PoskoState get state {
    if (!open) return PoskoState.tutup;
    if (occupants >= capacity) return PoskoState.penuh;
    if (fill >= 0.8) return PoskoState.hampirPenuh;
    return PoskoState.tersedia;
  }

  bool get hasCoordinates => isValidCoord(lat, lng);

  Iterable<LogisticItem> get lowStock => logistics.where((i) => i.low);
}

/// Siaran darurat (alarm) dari pusat/petugas ke warga di wilayah bencana.
class EmergencyBroadcast {
  final String id;
  final String title;
  final String message;
  final Severity severity;

  /// Wilayah tujuan (semua pengguna di dalamnya menjadi calon penerima).
  final String areaId;

  /// Bila diisi, penerima yang lokasinya diketahui disaring menurut radius.
  final double? lat;
  final double? lng;
  final double? radiusM;
  final String senderEmail;
  final String senderName;
  final String senderRole;
  final DateTime createdAt;

  /// Email penerima yang dikirimi siaran.
  final Set<String> deliveredTo;

  /// Email penerima yang menekan "Saya mengerti".
  final Set<String> ackBy;

  EmergencyBroadcast({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.areaId,
    required this.senderEmail,
    required this.senderName,
    required this.senderRole,
    required this.createdAt,
    this.lat,
    this.lng,
    this.radiusM,
    Set<String>? deliveredTo,
    Set<String>? ackBy,
  })  : deliveredTo = deliveredTo ?? <String>{},
        ackBy = ackBy ?? <String>{};

  bool get hasCenter => isValidCoord(lat, lng) && radiusM != null;

  int get recipients => deliveredTo.length;
  int get acknowledged => ackBy.length;
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String kind; // alert | sos | broadcast | info
  final DateTime createdAt;
  bool read;

  /// Untuk kind == broadcast: id siaran terkait.
  final String? broadcastId;
  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
    this.read = false,
    this.broadcastId,
  });
}

class SosEvent {
  final String id;
  final String ownerEmail;
  final String ownerName;
  final String areaId;
  final DateTime createdAt;
  final int contacts;
  final int neighbors;
  final bool viaSms;
  final double? lat;
  final double? lng;
  DateTime? resolvedAt;
  DateTime? cancelledAt;
  String? cancelReason;

  /// Pengawas yang menanggapi SOS ini.
  String? respondedBy;
  DateTime? respondedAt;

  SosEvent({
    required this.id,
    required this.ownerEmail,
    required this.ownerName,
    required this.areaId,
    required this.createdAt,
    required this.contacts,
    required this.neighbors,
    required this.viaSms,
    this.lat,
    this.lng,
  });

  bool get isActive => resolvedAt == null && cancelledAt == null;

  bool get hasCoordinates => isValidCoord(lat, lng);

  String get statusLabel {
    if (isActive) {
      return respondedBy == null ? 'Aktif' : 'Aktif, ditanggapi $respondedBy';
    }
    if (cancelledAt != null) return 'Dibatalkan: ${cancelReason ?? '-'}';
    return 'Selesai (pengguna aman)';
  }
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'baru saja';
  if (d.inMinutes < 60) return '${d.inMinutes} menit lalu';
  if (d.inHours < 24) return '${d.inHours} jam lalu';
  return '${d.inDays} hari lalu';
}

String clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

/// Contoh: "12/10/2026 14.30".
String dateTimeLabel(DateTime t) {
  final d = '${t.day.toString().padLeft(2, '0')}/'
      '${t.month.toString().padLeft(2, '0')}/${t.year}';
  return '$d ${clock(t)}';
}

String dateLabel(DateTime t) => '${t.day.toString().padLeft(2, '0')}/'
    '${t.month.toString().padLeft(2, '0')}/${t.year}';
