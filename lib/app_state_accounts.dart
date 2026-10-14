part of 'app_state.dart';

/// Hak akses, persetujuan akun, dan manajemen akun terpusat (Super Admin).
extension AppStateAccounts on AppState {
  // ---------------------------------------------------------- peran

  bool _hasRole(UserRole role) =>
      currentUser != null &&
      currentUser!.role == role &&
      currentUser!.approved;

  bool get isSuperAdmin => _hasRole(UserRole.superAdmin);

  /// Admin Wilayah yang sudah aktif.
  bool get isAdmin => _hasRole(UserRole.admin);

  bool get isKetuaRt => _hasRole(UserRole.ketuaRt);

  bool get isPetugas => _hasRole(UserRole.petugas);

  bool get isRelawan => _hasRole(UserRole.relawan);

  /// Pemverifikasi laporan: Ketua RT dan Admin Wilayah yang sudah aktif.
  bool get isModerator => isKetuaRt || isAdmin;

  /// Pengurus yang boleh mengelola pengumuman dan nomor penting setempat.
  bool get canPostAnnouncement => isModerator || isPetugas;

  /// Pengawas yang menerima dan memantau SOS di wilayahnya.
  bool get canSeeSos => isModerator || isPetugas || isRelawan || isSuperAdmin;

  /// Boleh menyiarkan peringatan darurat (pusat atau petugas).
  bool get canBroadcast => isAdmin || isPetugas || isSuperAdmin;

  /// Boleh mengekspor rekap resmi (PDF/Excel).
  bool get canExport => isModerator || isPetugas || isSuperAdmin;

  /// Boleh membuka menu persetujuan akun.
  bool get canApproveAccounts => isAdmin || isKetuaRt || isSuperAdmin;

  /// Boleh membuat RW/RT baru.
  bool get canManageRegions => isAdmin || isSuperAdmin;

  /// Boleh membantu pekerjaan lapangan (petugas, relawan, pengurus).
  bool get isResponder => isModerator || isPetugas || isRelawan;

  // ------------------------------------------------------ wilayah

  /// Wilayah kewenangan pengguna: RT (warga, Ketua RT), kelurahan (Petugas
  /// dan Relawan), wilayah yang ditetapkan (Admin), atau seluruh Indonesia
  /// (Super Admin).
  String authorityAreaOf(AppUser u) {
    switch (u.role) {
      case UserRole.superAdmin:
        return Regions.rootId;
      case UserRole.petugas:
      case UserRole.relawan:
        return Regions.ancestorAtLevel(u.areaId, RegionLevel.kelurahan) ??
            u.areaId;
      case UserRole.warga:
      case UserRole.ketuaRt:
      case UserRole.admin:
        return u.areaId;
    }
  }

  String get myAuthorityArea => authorityAreaOf(me);

  /// Dua wilayah saling mencakup (salah satunya berada di dalam yang lain).
  bool _overlaps(String a, String b) =>
      Regions.isWithin(a, b) || Regions.isWithin(b, a);

  /// Pesan kesalahan bila [areaId] tidak cocok dengan [role], atau null.
  String? areaErrorFor(UserRole role, String areaId) {
    if (role == UserRole.superAdmin) {
      return areaId == Regions.rootId
          ? null
          : 'Super Admin tidak dibatasi wilayah.';
    }
    final level = Regions.levelOf(areaId);
    if (level == null) return 'Wilayah tidak dikenal.';
    if (role == UserRole.admin) {
      const allowed = {
        RegionLevel.kelurahan,
        RegionLevel.kecamatan,
        RegionLevel.kota,
      };
      return allowed.contains(level)
          ? null
          : 'Admin Wilayah mengawasi kelurahan, kecamatan, atau kota.';
    }
    return level == RegionLevel.rt ? null : 'Pilih wilayah sampai tingkat RT.';
  }

  // -------------------------------------------- persetujuan akun

  /// Apakah [approver] berwenang menyetujui/menolak akun [target]:
  ///  - Super Admin: semua akun.
  ///  - Admin Wilayah: Ketua RT, Petugas, Relawan di wilayahnya.
  ///  - Ketua RT: Relawan yang mendaftar di RT-nya.
  bool canApprove(AppUser approver, AppUser target) {
    if (!approver.approved || approver.email == target.email) return false;
    if (!target.role.needsApproval) return false;
    switch (approver.role) {
      case UserRole.superAdmin:
        return true;
      case UserRole.admin:
        return Regions.isWithin(target.areaId, approver.areaId);
      case UserRole.ketuaRt:
        return target.role == UserRole.relawan &&
            Regions.isWithin(target.areaId, approver.areaId);
      case UserRole.warga:
      case UserRole.petugas:
      case UserRole.relawan:
        return false;
    }
  }

  /// Akun yang menunggu persetujuan dan boleh diputuskan pengguna ini.
  List<AppUser> get pendingApprovals {
    final u = currentUser;
    if (u == null || !canApproveAccounts) return [];
    return users
        .where((x) => x.status == AccountStatus.menunggu && canApprove(u, x))
        .toList();
  }

  /// Pengurus yang berwenang atas akun [target] (untuk pemberitahuan).
  Iterable<AppUser> _approversFor(AppUser target) =>
      users.where((a) => a.status == AccountStatus.aktif && canApprove(a, target));

  void _notifyApprovers(AppUser target) {
    for (final a in _approversFor(target)) {
      _notify(
        a,
        'Pendaftaran ${target.role.label} baru',
        '${target.name} (${Regions.shortName(target.areaId)}) menunggu persetujuan Anda.',
        'info',
      );
    }
  }

  void approve(AppUser target) {
    final u = currentUser;
    if (u == null || !canApprove(u, target)) return;
    if (target.status != AccountStatus.menunggu) return;
    target.status = AccountStatus.aktif;
    target.statusNote = null;
    _notify(
      target,
      'Akun ${target.role.label} disetujui',
      'Anda kini dapat menjalankan tugas sebagai ${target.role.label} di '
          '${Regions.shortName(authorityAreaOf(target))}.',
      'info',
    );
    _changed();
  }

  /// Menolak pendaftaran; alasan wajib. Mengembalikan pesan error atau null.
  String? rejectAccount(AppUser target, String reason) {
    final u = currentUser;
    if (u == null || !canApprove(u, target)) {
      return 'Anda tidak berwenang atas akun ini.';
    }
    if (target.status != AccountStatus.menunggu) {
      return 'Akun ini tidak sedang menunggu persetujuan.';
    }
    final r = reason.trim();
    if (r.isEmpty) return 'Alasan penolakan wajib diisi.';
    target.status = AccountStatus.ditolak;
    target.statusNote = r;
    _notify(
      target,
      'Pendaftaran ditolak',
      'Pendaftaran ${target.role.label} ditolak. Alasan: $r',
      'info',
    );
    _changed();
    return null;
  }

  // -------------------------------------- manajemen akun (Super Admin)

  /// Semua akun, diurutkan menurut peran lalu nama.
  List<AppUser> get allAccounts {
    final out = [...users];
    out.sort((a, b) {
      final c = a.role.index.compareTo(b.role.index);
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  static final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Super Admin membuat akun dengan peran dan wilayah apa pun. Akun langsung
  /// aktif. Mengembalikan pesan error atau null.
  String? createAccount({
    required String name,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
    required String areaId,
  }) {
    if (!isSuperAdmin) return 'Hanya Super Admin yang boleh membuat akun.';
    if (name.trim().isEmpty) return 'Nama wajib diisi.';
    final e = email.trim().toLowerCase();
    if (!_emailRe.hasMatch(e)) return 'Format email tidak valid.';
    if (userByEmail(e) != null) return 'Email sudah terdaftar.';
    if (password.length < 6) return 'Kata sandi minimal 6 karakter.';
    final areaError = areaErrorFor(role, areaId);
    if (areaError != null) return areaError;
    users.add(AppUser(
      name: name.trim(),
      email: e,
      phone: phone.trim(),
      password: password,
      role: role,
      areaId: areaId,
    ));
    _changed();
    return null;
  }

  /// Mengubah peran dan/atau wilayah kewenangan (regional scoping) akun.
  /// Berlaku langsung tanpa mengubah kode aplikasi.
  String? updateAccount(
    AppUser target, {
    String? name,
    String? phone,
    UserRole? role,
    String? areaId,
  }) {
    if (!isSuperAdmin) return 'Hanya Super Admin yang boleh mengubah akun.';
    if (target.email == me.email && role != null && role != target.role) {
      return 'Peran akun Anda sendiri tidak dapat diubah.';
    }
    final newRole = role ?? target.role;
    final newArea = areaId ?? target.areaId;
    final areaError = areaErrorFor(newRole, newArea);
    if (areaError != null) return areaError;
    if (name != null && name.trim().isEmpty) return 'Nama wajib diisi.';

    final changedScope = newRole != target.role || newArea != target.areaId;
    if (name != null) target.name = name.trim();
    if (phone != null) target.phone = phone.trim();
    target.role = newRole;
    target.areaId = newArea;
    if (changedScope) {
      _notify(
        target,
        'Hak akses diperbarui',
        'Peran Anda kini ${newRole.label} untuk ${Regions.shortName(authorityAreaOf(target))}.',
        'info',
      );
    }
    _syncPush();
    _changed();
    return null;
  }

  /// Mengaktifkan, menonaktifkan, atau menolak akun. Alasan wajib untuk
  /// penonaktifan/penolakan.
  String? setAccountStatus(
    AppUser target,
    AccountStatus status, {
    String? note,
  }) {
    if (!isSuperAdmin) return 'Hanya Super Admin yang boleh mengubah status akun.';
    if (target.email == me.email) {
      return 'Status akun Anda sendiri tidak dapat diubah.';
    }
    final n = (note ?? '').trim();
    if ((status == AccountStatus.dinonaktifkan ||
            status == AccountStatus.ditolak) &&
        n.isEmpty) {
      return 'Alasan wajib diisi.';
    }
    target.status = status;
    target.statusNote = status == AccountStatus.aktif ? null : n;
    if (status == AccountStatus.aktif) {
      _notify(target, 'Akun diaktifkan', 'Akun Anda aktif kembali.', 'info');
    }
    _changed();
    return null;
  }

  /// Mengatur kata sandi baru untuk akun (mis. warga lupa dan tak punya email).
  String? resetAccountPassword(AppUser target, String newPassword) {
    if (!isSuperAdmin) return 'Hanya Super Admin yang boleh mengatur sandi.';
    if (newPassword.length < 6) return 'Kata sandi minimal 6 karakter.';
    target.password = newPassword;
    _failedLogins.remove(target.email);
    _lockedUntil.remove(target.email);
    _changed();
    return null;
  }

  // ------------------------------------------------- wilayah (RW/RT)

  /// Pengurus menambah RW (di bawah kelurahan) atau RT (di bawah RW) yang
  /// belum ada di data nasional. Admin hanya di dalam wilayahnya.
  Region? addLocalRegion(String parentId, String number) {
    if (!canManageRegions) return null;
    if (!isSuperAdmin && !Regions.isWithin(parentId, myAuthorityArea)) {
      return null;
    }
    final r = Regions.addLocalUnit(parentId, number);
    if (r != null) _changed();
    return r;
  }

  /// Ringkasan nasional untuk beranda Super Admin.
  Map<String, int> get nationalSummary => {
        'Akun': users.length,
        'Menunggu persetujuan':
            users.where((u) => u.status == AccountStatus.menunggu).length,
        'Laporan aktif': reports.where((r) => r.status.isActive).length,
        'SOS aktif': sosEvents.where((e) => e.isActive).length,
        'Posko': evacuationPoints.length,
      };
}
