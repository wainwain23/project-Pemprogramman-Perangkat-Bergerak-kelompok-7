part of 'app_state.dart';

/// Laporan kejadian: daftar, duplikat berdasarkan jarak, riwayat (audit trail),
/// verifikasi, penugasan petugas lapangan, dan kondisi lapangan.
extension AppStateReports on AppState {
  // ----------------------------------------------------------- umum

  /// Akun yang masih bisa menerima pemberitahuan.
  bool _reachable(AppUser u) =>
      u.status == AccountStatus.aktif || u.status == AccountStatus.menunggu;

  /// Pengurus pemverifikasi (Ketua RT/Admin aktif) yang berwenang atas [areaId].
  Iterable<AppUser> _moderatorsFor(String areaId) => users.where((u) =>
      u.approved &&
      (u.role == UserRole.ketuaRt || u.role == UserRole.admin) &&
      Regions.isWithin(areaId, authorityAreaOf(u)));

  /// Pengurus, petugas, dan relawan aktif yang berwenang atas [areaId].
  Iterable<AppUser> _respondersFor(String areaId) => users.where((u) =>
      u.approved &&
      (u.role == UserRole.ketuaRt ||
          u.role == UserRole.admin ||
          u.role == UserRole.petugas ||
          u.role == UserRole.relawan) &&
      Regions.isWithin(areaId, authorityAreaOf(u)));

  void _log(
    Report r,
    String action, {
    ReportStatus? status,
    String? note,
    AppUser? actor,
  }) {
    final a = actor ?? currentUser;
    r.timeline.add(TimelineEvent(
      at: DateTime.now(),
      actor: a?.name ?? 'Sistem',
      role: a?.role.label ?? 'Sistem',
      action: action,
      status: status,
      note: note,
    ));
  }

  /// Peringatan ke warga satu kelurahan dengan kejadian. Hanya untuk tingkat
  /// Waspada/Bahaya agar notifikasi tidak berlebihan. Simulasi push (FCM).
  void _alertNearby(Report r, {String? exceptEmail}) {
    if (r.severity == Severity.info) return;
    final kel = Regions.ancestorAtLevel(r.areaId, RegionLevel.kelurahan);
    if (kel == null) return;
    for (final u in users) {
      if (!u.alertsEnabled || u.email == exceptEmail || !_reachable(u)) continue;
      if (!Regions.isWithin(u.areaId, kel)) continue;
      _notify(
        u,
        '${r.severity.label}: ${r.category} di sekitar Anda',
        '${r.location} (${Regions.shortName(r.areaId)})',
        'alert',
      );
    }
  }

  void _notifyAuthor(Report r, String title, String body, {String? except}) {
    if (r.authorEmail == except) return;
    final a = userByEmail(r.authorEmail);
    if (a != null) _notify(a, title, body, 'info');
  }

  void _announceNewReport(Report r) {
    for (final m in _moderatorsFor(r.areaId)) {
      if (m.email == r.authorEmail) continue;
      _notify(
        m,
        'Laporan baru: ${r.category}',
        '${r.location} (${Regions.shortName(r.areaId)}) menunggu verifikasi.',
        'info',
      );
    }
  }

  /// Dipanggil saat laporan offline berhasil dikirim.
  void _markSynced(Report r) {
    _log(r, 'Terkirim ke server (sinkronisasi)');
    _announceNewReport(r);
  }

  // ------------------------------------------------------- daftar

  String? scopeAreaId(ReportScope s) {
    final u = currentUser;
    if (u == null) return null;
    return Regions.ancestorAtLevel(u.areaId, s.level);
  }

  /// Cakupan yang tersedia bagi pengguna. Admin kelurahan, misalnya, tidak
  /// punya cakupan RT/RW (akan selalu kosong), jadi pilihan itu disembunyikan.
  List<ReportScope> get availableScopes => [
        for (final s in ReportScope.values)
          if (scopeAreaId(s) != null) s,
      ];

  bool _visible(Report r) {
    if (r.status != ReportStatus.ditolak) return true;
    final u = currentUser;
    if (u == null) return false;
    return r.authorEmail == u.email || canModerate(r);
  }

  List<Report> reportsInScope(ReportScope s) {
    final a = scopeAreaId(s);
    if (a == null) return [];
    final out = reports
        .where((r) => Regions.isWithin(r.areaId, a) && _visible(r))
        .toList();
    out.sort((x, y) => y.createdAt.compareTo(x.createdAt));
    return out;
  }

  List<Report> get myReports {
    final u = currentUser;
    if (u == null) return [];
    final out = reports.where((r) => r.authorEmail == u.email).toList();
    out.sort((x, y) => y.createdAt.compareTo(x.createdAt));
    return out;
  }

  Report? reportById(String id) {
    for (final r in reports) {
      if (r.id == id) return r;
    }
    return null;
  }

  // ------------------------------------------------------- hak akses

  /// Verifikasi/tolak/tugaskan: Ketua RT atau Admin di wilayah laporan.
  bool canModerate(Report r) {
    if (currentUser == null || !isModerator) return false;
    return Regions.isWithin(r.areaId, myAuthorityArea);
  }

  /// Mengubah status penanganan (diproses/selesai) dan melaporkan kondisi
  /// lapangan: pemverifikasi di wilayahnya, atau Petugas Lapangan di
  /// kelurahan kewenangannya.
  bool canHandle(Report r) {
    if (currentUser == null) return false;
    if (canModerate(r)) return true;
    return isPetugas && Regions.isWithin(r.areaId, myAuthorityArea);
  }

  bool canAssign(Report r) =>
      canModerate(r) &&
      (r.status == ReportStatus.terverifikasi ||
          r.status == ReportStatus.diproses);

  /// Petugas aktif yang berwenang atas lokasi laporan.
  List<AppUser> assignablePetugas(Report r) => users
      .where((u) =>
          u.role == UserRole.petugas &&
          u.approved &&
          Regions.isWithin(r.areaId, authorityAreaOf(u)))
      .toList();

  // ------------------------------------------------------- duplikat

  /// Laporan aktif sejenis di dekat titik yang sama dalam [duplicateWindow].
  /// Bila titik koordinat tersedia di kedua laporan, dipakai jarak (radius
  /// [AppConfig.duplicateRadiusM]); bila tidak, dipakai kesamaan RT.
  Report? findPossibleDuplicate(String category, {double? lat, double? lng}) {
    final u = currentUser;
    if (u == null) return null;
    final since = DateTime.now().subtract(AppState.duplicateWindow);
    final hasPoint = isValidCoord(lat, lng);
    Report? best;
    for (final r in reports) {
      if (!r.status.isActive ||
          r.category != category ||
          !r.createdAt.isAfter(since)) {
        continue;
      }
      final bool near;
      if (hasPoint && r.hasCoordinates) {
        near = haversineM(lat!, lng!, r.lat!, r.lng!) <=
            AppConfig.duplicateRadiusM;
      } else {
        near = r.areaId == u.areaId;
      }
      if (!near) continue;
      if (best == null || r.createdAt.isAfter(best.createdAt)) best = r;
    }
    return best;
  }

  // ------------------------------------------------------- membuat

  /// Mengembalikan pesan error, atau null bila berhasil.
  String? addReport({
    required String category,
    required String description,
    required String location,
    String? photoPath,
    double? lat,
    double? lng,
    double? accuracyM,
  }) {
    final u = currentUser;
    if (u == null) return 'Silakan masuk terlebih dahulu';
    final hourAgo = DateTime.now().subtract(const Duration(hours: 1));
    final recent = reports
        .where((r) => r.authorEmail == u.email && r.createdAt.isAfter(hourAgo))
        .length;
    if (recent >= AppState.maxReportsPerHour) {
      return 'Batas ${AppState.maxReportsPerHour} laporan per jam tercapai. Coba lagi nanti.';
    }
    final hasPoint = isValidCoord(lat, lng);
    final report = Report(
      id: _newId('r'),
      authorName: u.name,
      authorEmail: u.email,
      category: category,
      description: description,
      areaId: u.areaId,
      location: location,
      createdAt: DateTime.now(),
      photoPath: photoPath,
      lat: hasPoint ? lat : null,
      lng: hasPoint ? lng : null,
      accuracyM: hasPoint ? accuracyM : null,
      severity: categoryInfo(category).defaultSeverity,
      pendingSync: offline,
      confirmedBy: {u.email},
    );
    _log(
      report,
      'Laporan dibuat',
      status: ReportStatus.menunggu,
      note: offline ? 'Disimpan di perangkat, menunggu sinkron' : null,
    );
    reports.insert(0, report);
    if (hasPoint) updateMyLocation(lat!, lng!);
    if (!offline) {
      _notify(
        u,
        'Laporan terkirim',
        '${report.category} - ${report.location} menunggu verifikasi.',
        'info',
      );
      _announceNewReport(report);
    }
    _changed();
    return null;
  }

  // ------------------------------------------------------- konfirmasi

  /// Apakah pengguna boleh menekan "Saya lihat" pada laporan ini. Hanya warga
  /// satu kelurahan dengan lokasi kejadian, agar verifikasi otomatis tidak
  /// bisa dipicu oleh akun dari wilayah lain.
  bool canConfirm(Report r) {
    final u = currentUser;
    if (u == null) return false;
    if (!r.status.isActive) return false;
    if (r.confirmedBy.contains(u.email)) return false;
    final kel = Regions.ancestorAtLevel(r.areaId, RegionLevel.kelurahan);
    return kel != null && Regions.isWithin(u.areaId, kel);
  }

  /// Konfirmasi "saya juga melihat". Mengembalikan true bila sukses.
  bool confirmReport(Report r) {
    final u = currentUser;
    if (u == null || !canConfirm(r)) return false;
    r.confirmedBy.add(u.email);
    r.confirmations++;
    if (r.status == ReportStatus.menunggu &&
        r.confirmations >= AppState.autoVerifyThreshold) {
      r.status = ReportStatus.terverifikasi;
      r.verifiedAt = DateTime.now();
      if (r.severity == Severity.info) r.severity = Severity.waspada;
      r.comments.add(ReportComment(
        author: 'Sistem',
        text:
            'Terverifikasi otomatis karena ${AppState.autoVerifyThreshold} warga berbeda mengonfirmasi.',
        createdAt: DateTime.now(),
        official: true,
      ));
      r.timeline.add(TimelineEvent(
        at: DateTime.now(),
        actor: 'Sistem',
        role: 'Sistem',
        action:
            'Terverifikasi otomatis (${AppState.autoVerifyThreshold} konfirmasi warga)',
        status: ReportStatus.terverifikasi,
      ));
      _alertNearby(r, exceptEmail: u.email);
      _notifyAuthor(
        r,
        'Laporan terverifikasi',
        '${r.category} di ${r.location} terverifikasi otomatis.',
        except: u.email,
      );
    }
    _changed();
    return true;
  }

  void addComment(Report r, String text) {
    final u = currentUser;
    if (u == null || text.trim().isEmpty) return;
    r.comments.add(ReportComment(
      author: u.name,
      text: text.trim(),
      createdAt: DateTime.now(),
      official: canHandle(r),
    ));
    _changed();
  }

  // ------------------------------------------------------- status

  /// Mengubah status. Alur yang valid:
  ///  - menunggu -> terverifikasi atau ditolak (pemverifikasi, tolak wajib alasan)
  ///  - terverifikasi -> diproses (pemverifikasi atau petugas)
  ///  - terverifikasi/diproses -> selesai (pemverifikasi atau petugas)
  /// Setiap perubahan dicatat di riwayat. Mengembalikan perkiraan jumlah warga
  /// yang menerima peringatan (hanya saat verifikasi).
  int setStatus(
    Report r,
    ReportStatus status, {
    Severity? severity,
    String? reason,
  }) {
    final u = currentUser;
    if (u == null) return 0;
    final verifyStep =
        status == ReportStatus.terverifikasi || status == ReportStatus.ditolak;
    if (!(verifyStep ? canModerate(r) : canHandle(r))) return 0;
    final allowed = switch (status) {
      ReportStatus.terverifikasi => r.status == ReportStatus.menunggu,
      ReportStatus.ditolak => r.status == ReportStatus.menunggu &&
          reason != null &&
          reason.trim().isNotEmpty,
      ReportStatus.diproses => r.status == ReportStatus.terverifikasi,
      ReportStatus.selesai => r.status == ReportStatus.terverifikasi ||
          r.status == ReportStatus.diproses,
      ReportStatus.menunggu => false,
    };
    if (!allowed) return 0;
    r.status = status;
    final actor = '${u.name} (${u.role.label})';
    var recipients = 0;
    switch (status) {
      case ReportStatus.terverifikasi:
        r.verifiedAt = DateTime.now();
        if (severity != null) r.severity = severity;
        recipients = estimateRecipients(r.areaId, alertRadiusM);
        r.comments.add(ReportComment(
          author: actor,
          text: 'Laporan diverifikasi. Tingkat: ${r.severity.label}.',
          createdAt: DateTime.now(),
          official: true,
        ));
        _log(r, 'Diverifikasi',
            status: status, note: 'Tingkat: ${r.severity.label}');
        _alertNearby(r, exceptEmail: u.email);
        _notifyAuthor(
          r,
          'Laporan diverifikasi',
          '${r.category} di ${r.location} diverifikasi. Tingkat: ${r.severity.label}.',
          except: u.email,
        );
      case ReportStatus.ditolak:
        r.rejectReason = reason!.trim();
        r.comments.add(ReportComment(
          author: actor,
          text: 'Laporan ditolak. Alasan: ${r.rejectReason}',
          createdAt: DateTime.now(),
          official: true,
        ));
        _log(r, 'Ditolak', status: status, note: r.rejectReason);
        _notifyAuthor(
          r,
          'Laporan ditolak',
          '${r.category} di ${r.location}. Alasan: ${r.rejectReason}',
          except: u.email,
        );
      case ReportStatus.diproses:
        r.processedAt = DateTime.now();
        if (r.assigneeEmail == null && u.role == UserRole.petugas) {
          r.assigneeEmail = u.email;
          r.assigneeName = u.name;
          r.assignedAt = DateTime.now();
        }
        r.comments.add(ReportComment(
          author: actor,
          text: 'Penanganan dimulai.',
          createdAt: DateTime.now(),
          official: true,
        ));
        _log(r, 'Mulai ditangani', status: status);
        _notifyAuthor(
          r,
          'Laporan sedang ditangani',
          '${r.category} di ${r.location} mulai ditangani petugas.',
          except: u.email,
        );
      case ReportStatus.selesai:
        r.resolvedAt = DateTime.now();
        r.comments.add(ReportComment(
          author: actor,
          text: 'Masalah ditandai selesai.',
          createdAt: DateTime.now(),
          official: true,
        ));
        _log(r, 'Ditandai selesai', status: status);
        _notifyAuthor(
          r,
          'Laporan selesai ditangani',
          '${r.category} di ${r.location} ditandai selesai.',
          except: u.email,
        );
      case ReportStatus.menunggu:
        break;
    }
    _changed();
    return recipients;
  }

  // ------------------------------------------------------- tugas petugas

  /// Menugaskan laporan ke Petugas Lapangan. Mengembalikan pesan error atau null.
  String? assignReport(Report r, AppUser petugas) {
    final u = currentUser;
    if (u == null || !canAssign(r)) {
      return 'Anda tidak berwenang menugaskan laporan ini.';
    }
    if (!assignablePetugas(r).any((p) => p.email == petugas.email)) {
      return 'Petugas tidak berwenang di wilayah laporan ini.';
    }
    r.assigneeEmail = petugas.email;
    r.assigneeName = petugas.name;
    r.assignedAt = DateTime.now();
    r.comments.add(ReportComment(
      author: '${u.name} (${u.role.label})',
      text: 'Ditugaskan kepada ${petugas.name}.',
      createdAt: DateTime.now(),
      official: true,
    ));
    _log(r, 'Ditugaskan ke ${petugas.name}');
    _notify(
      petugas,
      'Tugas baru: ${r.category}',
      '${r.location} (${Regions.shortName(r.areaId)}) - tingkat ${r.severity.label}.',
      'info',
    );
    _changed();
    return null;
  }

  /// Petugas mengambil tugas yang belum ada penanggung jawabnya.
  String? claimTask(Report r) {
    final u = currentUser;
    if (u == null || !isPetugas || !canHandle(r)) {
      return 'Hanya Petugas Lapangan di wilayah ini yang bisa mengambil tugas.';
    }
    if (r.assigneeEmail != null) return 'Tugas sudah diambil petugas lain.';
    if (r.status != ReportStatus.terverifikasi &&
        r.status != ReportStatus.diproses) {
      return 'Laporan belum terverifikasi.';
    }
    r.assigneeEmail = u.email;
    r.assigneeName = u.name;
    r.assignedAt = DateTime.now();
    _log(r, 'Tugas diambil ${u.name}');
    _changed();
    return null;
  }

  /// Tugas yang ditugaskan kepada pengguna dan masih berjalan.
  List<Report> get myTasks {
    final u = currentUser;
    if (u == null) return [];
    final out = reports
        .where((r) => r.assigneeEmail == u.email && r.status.isActive)
        .toList();
    out.sort((a, b) {
      final c = b.severity.index.compareTo(a.severity.index);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return out;
  }

  /// Laporan terverifikasi di wilayah petugas yang belum ada penanggung jawab.
  List<Report> get availableTasks {
    final u = currentUser;
    if (u == null || !isPetugas) return [];
    final out = reports
        .where((r) =>
            r.status == ReportStatus.terverifikasi &&
            r.assigneeEmail == null &&
            canHandle(r))
        .toList();
    out.sort((a, b) {
      final c = b.severity.index.compareTo(a.severity.index);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return out;
  }

  /// Laporan kondisi riil di lapangan oleh petugas. Mengembalikan error atau null.
  String? addFieldReport(Report r, String text) {
    final u = currentUser;
    if (u == null || !canHandle(r)) {
      return 'Anda tidak berwenang melaporkan kondisi lapangan.';
    }
    final t = text.trim();
    if (t.length < 5) return 'Jelaskan kondisi lapangan (minimal 5 karakter).';
    if (!r.status.isActive) return 'Laporan ini sudah ditutup.';
    r.comments.add(ReportComment(
      author: '${u.name} (${u.role.label})',
      text: t,
      createdAt: DateTime.now(),
      official: true,
      field: true,
    ));
    _log(r, 'Laporan kondisi lapangan', note: t);
    _notifyAuthor(
      r,
      'Kabar dari lapangan',
      '${r.category} di ${r.location}: $t',
      except: u.email,
    );
    for (final m in _moderatorsFor(r.areaId)) {
      if (m.email == u.email) continue;
      _notify(m, 'Kondisi lapangan: ${r.category}', '${r.location}: $t', 'info');
    }
    _changed();
    return null;
  }
}
