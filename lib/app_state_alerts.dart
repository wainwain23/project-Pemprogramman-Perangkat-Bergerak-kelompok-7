part of 'app_state.dart';

/// Hasil pengiriman siaran darurat.
class BroadcastResult {
  final EmergencyBroadcast? broadcast;
  final String? error;
  const BroadcastResult.ok(this.broadcast) : error = null;
  const BroadcastResult.fail(this.error) : broadcast = null;

  bool get success => broadcast != null;
}

/// SOS, siaran darurat (alarm), dan pengumuman resmi.
extension AppStateAlerts on AppState {
  // ----------------------------------------------------------------- SOS

  /// Riwayat SOS milik pengguna yang sedang masuk (terbaru di atas).
  List<SosEvent> get sosHistory {
    final u = currentUser;
    if (u == null) return [];
    return sosEvents.where((e) => e.ownerEmail == u.email).toList();
  }

  SosEvent? get activeSos {
    for (final e in sosHistory) {
      if (e.isActive) return e;
    }
    return null;
  }

  /// Mengirim SOS. [lat]/[lng] dari GPS bila tersedia.
  SosEvent triggerSos({double? lat, double? lng}) {
    final existing = activeSos;
    if (existing != null) return existing; // cegah SOS ganda
    final u = me;
    final hasPoint = isValidCoord(lat, lng);
    final e = SosEvent(
      id: _newId('s'),
      ownerEmail: u.email,
      ownerName: u.name,
      areaId: u.areaId,
      createdAt: DateTime.now(),
      contacts: myContacts.length,
      neighbors: estimateRecipients(u.areaId, alertRadiusM),
      viaSms: offline,
      lat: hasPoint ? lat : null,
      lng: hasPoint ? lng : null,
    );
    sosEvents.insert(0, e);
    if (hasPoint) updateMyLocation(lat!, lng!);
    // Pengawas wilayah (pengurus, petugas, relawan) menerima SOS.
    for (final m in _respondersFor(u.areaId)) {
      if (m.email == u.email) continue;
      _notify(
        m,
        'SOS dari ${u.name}',
        '${Regions.shortName(u.areaId)} - ${clock(e.createdAt)}',
        'sos',
      );
    }
    _changed();
    return e;
  }

  /// Pengguna menyatakan sudah aman.
  void resolveSos() {
    activeSos?.resolvedAt = DateTime.now();
    _changed();
  }

  /// Membatalkan SOS dengan alasan (mis. salah pencet).
  void cancelSos(String reason) {
    final e = activeSos;
    if (e == null) return;
    e.cancelledAt = DateTime.now();
    e.cancelReason = reason.trim().isEmpty ? 'Tanpa alasan' : reason.trim();
    _changed();
  }

  /// SOS di wilayah kewenangan pengawas (bukan milik sendiri). Yang aktif
  /// lebih dulu, lalu yang terbaru.
  List<SosEvent> sosInMyArea({bool activeOnly = true}) {
    final u = currentUser;
    if (u == null || !canSeeSos) return [];
    final area = myAuthorityArea;
    final out = sosEvents
        .where((e) =>
            e.ownerEmail != u.email &&
            Regions.isWithin(e.areaId, area) &&
            (!activeOnly || e.isActive))
        .toList();
    out.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return out;
  }

  /// Pengawas menanggapi SOS. Mengembalikan pesan error atau null.
  String? respondSos(SosEvent e) {
    final u = currentUser;
    if (u == null || !canSeeSos) return 'Anda tidak berwenang menanggapi SOS.';
    if (!Regions.isWithin(e.areaId, myAuthorityArea)) {
      return 'SOS ini di luar wilayah Anda.';
    }
    if (!e.isActive) return 'SOS sudah ditutup.';
    if (e.respondedBy != null) return 'SOS sudah ditanggapi ${e.respondedBy}.';
    e.respondedBy = '${u.name} (${u.role.label})';
    e.respondedAt = DateTime.now();
    final owner = userByEmail(e.ownerEmail);
    if (owner != null) {
      _notify(
        owner,
        'SOS Anda ditanggapi',
        '${u.name} (${u.role.label}) sedang menuju atau menghubungi Anda.',
        'info',
      );
    }
    _changed();
    return null;
  }

  // ------------------------------------------------------ siaran darurat

  /// Siaran yang dikirim pengguna ini (terbaru di atas).
  List<EmergencyBroadcast> get sentBroadcasts {
    final u = currentUser;
    if (u == null) return [];
    return broadcasts.where((b) => b.senderEmail == u.email).toList();
  }

  /// Siaran yang pernah diterima pengguna ini (terbaru di atas).
  List<EmergencyBroadcast> get receivedBroadcasts {
    final u = currentUser;
    if (u == null) return [];
    return broadcasts.where((b) => b.deliveredTo.contains(u.email)).toList();
  }

  EmergencyBroadcast? broadcastById(String? id) {
    if (id == null) return null;
    for (final b in broadcasts) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Menyiarkan peringatan darurat ke seluruh pengguna di [areaId] (bawaan:
  /// wilayah kewenangan pengirim). Bila [lat]/[lng]/[radiusM] diisi, penerima
  /// yang lokasinya diketahui disaring menurut radius; yang lokasinya tidak
  /// diketahui tetap menerima (lebih baik berlebih daripada terlewat).
  /// Siaran darurat tetap dikirim walau penerima menonaktifkan "Peringatan
  /// sekitar". Pada versi lengkap server mengirim ke topik FCM wilayah.
  BroadcastResult sendBroadcast({
    required String title,
    required String message,
    required Severity severity,
    String? areaId,
    double? lat,
    double? lng,
    double? radiusM,
  }) {
    final u = currentUser;
    if (u == null || !canBroadcast) {
      return const BroadcastResult.fail(
          'Hanya pusat atau petugas yang boleh menyiarkan peringatan darurat.');
    }
    final t = title.trim();
    final m = message.trim();
    if (t.isEmpty) return const BroadcastResult.fail('Judul wajib diisi.');
    if (t.length > 80) {
      return const BroadcastResult.fail('Judul maksimal 80 karakter.');
    }
    if (m.length < 5) {
      return const BroadcastResult.fail('Isi pesan minimal 5 karakter.');
    }
    final area = areaId ?? myAuthorityArea;
    if (area != Regions.rootId && Regions.byId(area) == null) {
      return const BroadcastResult.fail('Wilayah tujuan tidak dikenal.');
    }
    if (!isSuperAdmin && !Regions.isWithin(area, myAuthorityArea)) {
      return const BroadcastResult.fail(
          'Wilayah tujuan di luar kewenangan Anda.');
    }
    final hasCenter = isValidCoord(lat, lng);
    if (radiusM != null) {
      if (!hasCenter) {
        return const BroadcastResult.fail(
            'Titik pusat radius belum ada. Ambil lokasi dulu atau kosongkan radius.');
      }
      if (radiusM < 100 || radiusM > 50000) {
        return const BroadcastResult.fail('Radius harus 100 m sampai 50 km.');
      }
    }

    final b = EmergencyBroadcast(
      id: _newId('bc'),
      title: t,
      message: m,
      severity: severity,
      areaId: area,
      lat: hasCenter && radiusM != null ? lat : null,
      lng: hasCenter && radiusM != null ? lng : null,
      radiusM: radiusM,
      senderEmail: u.email,
      senderName: u.name,
      senderRole: u.role.label,
      createdAt: DateTime.now(),
    );
    for (final r in _audience(area, b.lat, b.lng, b.radiusM, u.email)) {
      b.deliveredTo.add(r.email);
      _notify(
        r,
        'SIARAN DARURAT: ${b.title}',
        b.message,
        'broadcast',
        broadcastId: b.id,
      );
      _pendingAlarms.putIfAbsent(r.email, () => <String>[]).add(b.id);
    }
    broadcasts.insert(0, b);
    _notify(
      u,
      'Siaran darurat terkirim',
      '"${b.title}" dikirim ke ${b.recipients} pengguna di ${Regions.shortName(area)}.',
      'info',
    );
    _changed();
    return BroadcastResult.ok(b);
  }

  /// Calon penerima siaran: pengguna di [areaId]; bila titik pusat dan radius
  /// diberikan, yang lokasinya diketahui disaring menurut radius.
  List<AppUser> _audience(
    String areaId,
    double? lat,
    double? lng,
    double? radiusM,
    String? exceptEmail,
  ) {
    final center = radiusM != null && isValidCoord(lat, lng);
    final out = <AppUser>[];
    for (final r in users) {
      if (r.email == exceptEmail || !_reachable(r)) continue;
      if (!Regions.isWithin(r.areaId, areaId)) continue;
      if (center && r.hasLocation) {
        if (haversineM(lat!, lng!, r.lastLat!, r.lastLng!) > radiusM!) continue;
      }
      out.add(r);
    }
    return out;
  }

  /// Jumlah pengguna yang akan menerima siaran (untuk pratinjau sebelum kirim).
  int broadcastAudienceCount(
    String areaId, {
    double? lat,
    double? lng,
    double? radiusM,
  }) =>
      _audience(areaId, lat, lng, radiusM, currentUser?.email).length;

  /// Siaran darurat yang menunggu ditampilkan sebagai alarm untuk pengguna ini.
  EmergencyBroadcast? get pendingAlarm {
    final u = currentUser;
    if (u == null) return null;
    final ids = _pendingAlarms[u.email];
    if (ids == null) return null;
    for (final id in ids) {
      final b = broadcastById(id);
      if (b != null) return b;
    }
    return null;
  }

  /// Pengguna menekan "Saya mengerti": alarm berhenti dan tercatat.
  void acknowledgeAlarm(String broadcastId) {
    final u = currentUser;
    if (u == null) return;
    _pendingAlarms[u.email]?.remove(broadcastId);
    broadcastById(broadcastId)?.ackBy.add(u.email);
    for (final n in myNotifications) {
      if (n.broadcastId == broadcastId) n.read = true;
    }
    _changed();
  }

  /// Menerima siaran darurat dari FCM. Mengembalikan true bila ditampilkan
  /// sebagai alarm (sesuai wilayah dan radius pengguna).
  bool receiveRemoteBroadcast(PushBroadcast p) {
    final u = currentUser;
    if (u == null) return false;
    if (broadcastById(p.id) != null) return false; // sudah pernah diterima
    final area = p.areaId;
    if (area != null &&
        area != Regions.rootId &&
        Regions.byId(area) != null &&
        !Regions.isWithin(u.areaId, area)) {
      return false;
    }
    final hasCenter = isValidCoord(p.lat, p.lng) && p.radiusM != null;
    if (hasCenter && u.hasLocation) {
      if (haversineM(p.lat!, p.lng!, u.lastLat!, u.lastLng!) > p.radiusM!) {
        return false;
      }
    }
    final b = EmergencyBroadcast(
      id: p.id,
      title: p.title,
      message: p.message,
      severity: p.severity,
      areaId: area ?? u.areaId,
      lat: hasCenter ? p.lat : null,
      lng: hasCenter ? p.lng : null,
      radiusM: hasCenter ? p.radiusM : null,
      senderEmail: 'push',
      senderName: p.sender,
      senderRole: 'Pusat',
      createdAt: DateTime.now(),
    );
    b.deliveredTo.add(u.email);
    broadcasts.insert(0, b);
    _notify(u, 'SIARAN DARURAT: ${b.title}', b.message, 'broadcast',
        broadcastId: b.id);
    _pendingAlarms.putIfAbsent(u.email, () => <String>[]).add(b.id);
    _changed();
    return true;
  }

  // ----------------------------------------------------------- pengumuman

  List<Announcement> get myAnnouncements {
    final u = currentUser;
    if (u == null) return [];
    final out = announcements
        .where((a) => Regions.isWithin(u.areaId, a.areaId))
        .toList();
    out.sort((x, y) {
      if (x.pinned != y.pinned) return x.pinned ? -1 : 1;
      return y.createdAt.compareTo(x.createdAt);
    });
    return out;
  }

  /// Pengumuman penting/evakuasi terbaru untuk beranda.
  List<Announcement> get officialHighlights => myAnnouncements
      .where((a) => a.tag == 'Penting' || a.tag == 'Evakuasi')
      .take(3)
      .toList();

  /// Pengurus hanya boleh mengelola pengumuman di dalam wilayahnya sendiri
  /// (Ketua RT tidak boleh menyematkan pengumuman tingkat kota).
  bool canManageAnnouncement(Announcement a) {
    if (currentUser == null || !canPostAnnouncement) return false;
    return Regions.isWithin(a.areaId, myAuthorityArea);
  }

  void addAnnouncement(String tag, String title, String body) {
    final u = currentUser;
    if (u == null || !canPostAnnouncement) return;
    final area = myAuthorityArea;
    announcements.add(Announcement(
      id: _newId('a'),
      areaId: area,
      tag: tag,
      title: title,
      body: body,
      author: '${u.name} (${u.role.label})',
      createdAt: DateTime.now(),
    ));
    if (tag == 'Penting' || tag == 'Evakuasi') {
      for (final x in users) {
        if (x.email == u.email || !_reachable(x)) continue;
        if (!Regions.isWithin(x.areaId, area)) continue;
        _notify(
          x,
          tag == 'Evakuasi' ? 'Instruksi evakuasi' : 'Pengumuman penting',
          title,
          'info',
        );
      }
    }
    _changed();
  }

  void togglePin(Announcement a) {
    if (!canManageAnnouncement(a)) return;
    a.pinned = !a.pinned;
    _changed();
  }
}
