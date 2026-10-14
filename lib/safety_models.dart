import 'package:flutter/material.dart';

/// Status keselamatan mandiri anggota keluarga saat bencana.
enum SafetyStatus { aman, butuhBantuan, belumDiketahui }

extension SafetyStatusX on SafetyStatus {
  String get label => switch (this) {
        SafetyStatus.aman => 'Saya aman',
        SafetyStatus.butuhBantuan => 'Butuh bantuan',
        SafetyStatus.belumDiketahui => 'Belum diketahui',
      };

  /// Label untuk anggota keluarga selain diri sendiri.
  String get memberLabel => switch (this) {
        SafetyStatus.aman => 'Aman',
        SafetyStatus.butuhBantuan => 'Butuh bantuan',
        SafetyStatus.belumDiketahui => 'Belum diketahui',
      };

  IconData get icon => switch (this) {
        SafetyStatus.aman => Icons.check_circle,
        SafetyStatus.butuhBantuan => Icons.sos,
        SafetyStatus.belumDiketahui => Icons.help,
      };
}

class FamilyMember {
  final String id;
  String name;
  String relation;
  String phone;
  SafetyStatus status;
  DateTime updatedAt;

  FamilyMember({
    required this.id,
    required this.name,
    required this.relation,
    this.phone = '',
    this.status = SafetyStatus.belumDiketahui,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
}

enum MissingStatus { dicari, ditemukan }

extension MissingStatusX on MissingStatus {
  String get label => switch (this) {
        MissingStatus.dicari => 'Masih dicari',
        MissingStatus.ditemukan => 'Sudah ditemukan',
      };
}

/// Entri papan informasi orang hilang (warga yang terpisah saat evakuasi).
class MissingPerson {
  final String id;
  final String name;
  final int? age;
  final String description; // ciri-ciri
  final String lastSeen; // terakhir terlihat di mana
  final String areaId; // wilayah tempat pelapor mendaftarkan
  final String reporterEmail;
  final String reporterName;
  final String contactName;
  final String contactPhone;
  final DateTime createdAt;
  final String? photoPath;
  MissingStatus status;
  String? foundNote;
  DateTime? foundAt;

  MissingPerson({
    required this.id,
    required this.name,
    required this.description,
    required this.lastSeen,
    required this.areaId,
    required this.reporterEmail,
    required this.reporterName,
    required this.contactName,
    required this.contactPhone,
    required this.createdAt,
    this.age,
    this.photoPath,
    this.status = MissingStatus.dicari,
    this.foundNote,
    this.foundAt,
  });
}

enum HelpType { evakuasi, logistik, medis, koordinasi }

extension HelpTypeX on HelpType {
  String get label => switch (this) {
        HelpType.evakuasi => 'Evakuasi',
        HelpType.logistik => 'Logistik',
        HelpType.medis => 'Medis',
        HelpType.koordinasi => 'Koordinasi',
      };

  IconData get icon => switch (this) {
        HelpType.evakuasi => Icons.directions_run,
        HelpType.logistik => Icons.inventory_2,
        HelpType.medis => Icons.medical_services,
        HelpType.koordinasi => Icons.forum,
      };
}

enum HelpStatus { terbuka, diambil, selesai }

extension HelpStatusX on HelpStatus {
  String get label => switch (this) {
        HelpStatus.terbuka => 'Terbuka',
        HelpStatus.diambil => 'Sedang ditangani',
        HelpStatus.selesai => 'Selesai',
      };
}

/// Permintaan bantuan yang dikerjakan relawan (evakuasi, logistik, dst).
class HelpRequest {
  final String id;
  final HelpType type;
  final String title;
  final String description;
  final String areaId;
  final String createdByName;
  final String createdByEmail;
  final DateTime createdAt;

  /// manual | keluarga | logistik
  final String source;

  /// Rujukan otomatis (mis. id anggota keluarga atau barang logistik) agar
  /// permintaan yang sama tidak dibuat berulang.
  final String? refKey;
  final double? lat;
  final double? lng;
  HelpStatus status;
  String? claimedByEmail;
  String? claimedByName;
  DateTime? claimedAt;
  DateTime? doneAt;
  String? doneNote;

  HelpRequest({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.areaId,
    required this.createdByName,
    required this.createdByEmail,
    required this.createdAt,
    this.source = 'manual',
    this.refKey,
    this.lat,
    this.lng,
    this.status = HelpStatus.terbuka,
    this.claimedByEmail,
    this.claimedByName,
    this.claimedAt,
    this.doneAt,
    this.doneNote,
  });

  bool get isOpen => status != HelpStatus.selesai;
}

enum LocalContactKind { rumahSakit, puskesmas, pemadam, polisi, bpbd, lainnya }

extension LocalContactKindX on LocalContactKind {
  String get label => switch (this) {
        LocalContactKind.rumahSakit => 'Rumah Sakit',
        LocalContactKind.puskesmas => 'Puskesmas',
        LocalContactKind.pemadam => 'Pemadam Kebakaran',
        LocalContactKind.polisi => 'Polisi',
        LocalContactKind.bpbd => 'BPBD / SAR',
        LocalContactKind.lainnya => 'Lainnya',
      };

  IconData get icon => switch (this) {
        LocalContactKind.rumahSakit => Icons.local_hospital,
        LocalContactKind.puskesmas => Icons.medical_services,
        LocalContactKind.pemadam => Icons.local_fire_department,
        LocalContactKind.polisi => Icons.local_police,
        LocalContactKind.bpbd => Icons.health_and_safety,
        LocalContactKind.lainnya => Icons.phone,
      };
}

/// Nomor penting setempat (rumah sakit, puskesmas, BPBD) per wilayah, diisi
/// oleh pengurus wilayah.
class LocalContact {
  final String id;
  final String name;
  final String phone;
  final LocalContactKind kind;
  final String areaId;
  final String address;
  const LocalContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.kind,
    required this.areaId,
    this.address = '',
  });
}
