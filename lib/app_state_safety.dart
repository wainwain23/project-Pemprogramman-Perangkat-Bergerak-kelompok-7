part of 'app_state.dart';

/// Ringkasan keselamatan satu rumah tangga (untuk pengurus).
class HouseholdSafety {
  final AppUser owner;
  final List<FamilyMember> members;
  const HouseholdSafety(this.owner, this.members);

  int get safe => members.where((m) => m.status == SafetyStatus.aman).length;
  int get needHelp =>
      members.where((m) => m.status == SafetyStatus.butuhBantuan).length;
  int get unknown =>
      members.where((m) => m.status == SafetyStatus.belumDiketahui).length;
}

/// Total status keselamatan di wilayah pengurus.
class SafetyTotals {
  final int safe;
  final int needHelp;
  final int unknown;

  /// Akun warga di wilayah yang belum pernah membuka/memperbarui statusnya.
  final int notReported;
  const SafetyTotals(this.safe, this.needHelp, this.unknown, this.notReported);
}

/// Keselamatan keluarga, orang hilang, posko, logistik, relawan, dan kontak.
extension AppStateSafety on AppState {
  // ---------------------------------------------------------- kontak

  List<EmergencyContact> get myContacts => _contacts.putIfAbsent(
        me.email,
        () => buildDefaultPersonalContacts().toList(),
      );

  void addContact(EmergencyContact c) {
    myContacts.add(c);
    _changed();
  }

  void removeContact(EmergencyContact c) {
    myContacts.remove(c);
    _changed();
  }

  /// Nomor penting setempat (rumah sakit, puskesmas, BPBD) yang mencakup
  /// wilayah pengguna, yang paling lokal lebih dulu.
  List<LocalContact> get localContactsForMe {
    final u = currentUser;
    if (u == null) return [];
    final out =
        localContacts.where((c) => Regions.isWithin(u.areaId, c.areaId)).toList();
    out.sort((a, b) {
      final la = Regions.chain(a.areaId).length;
      final lb = Regions.chain(b.areaId).length;
      final c = lb.compareTo(la);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return out;
  }

  /// Pengurus menambah nomor penting untuk wilayahnya. Mengembalikan error atau null.
  String? addLocalContact({
    required String name,
    required String phone,
    required LocalContactKind kind,
    String address = '',
  }) {
    if (currentUser == null || !canPostAnnouncement) {
      return 'Hanya pengurus wilayah yang boleh menambah nomor penting.';
    }
    if (name.trim().isEmpty) return 'Nama wajib diisi.';
    if (phone.trim().replaceAll(RegExp(r'[^0-9]'), '').length < 3) {
      return 'Nomor telepon tidak valid.';
    }
    localContacts.add(LocalContact(
      id: _newId('lc'),
      name: name.trim(),
      phone: phone.trim(),
      kind: kind,
      areaId: myAuthorityArea,
      address: address.trim(),
    ));
    _changed();
    return null;
  }

  bool canManageLocalContact(LocalContact c) =>
      currentUser != null &&
      canPostAnnouncement &&
      Regions.isWithin(c.areaId, myAuthorityArea);

  void removeLocalContact(LocalContact c) {
    if (!canManageLocalContact(c)) return;
    localContacts.removeWhere((x) => x.id == c.id);
    _changed();
  }

  // ------------------------------------------------- keselamatan keluarga

  String get _selfMemberId => 'self';

  /// Anggota keluarga/rumah tangga pengguna. Entri pertama selalu diri sendiri.
  List<FamilyMember> get myFamily {
    final u = me;
    final list = _family.putIfAbsent(u.email, () => <FamilyMember>[]);
    if (!list.any((m) => m.id == _selfMemberId)) {
      list.insert(
        0,
        FamilyMember(id: _selfMemberId, name: u.name, relation: 'Saya'),
      );
    }
    return list;
  }

  String? addFamilyMember({
    required String name,
    required String relation,
    String phone = '',
  }) {
    if (currentUser == null) return 'Silakan masuk terlebih dahulu';
    if (name.trim().isEmpty) return 'Nama wajib diisi.';
    if (relation.trim().isEmpty) return 'Hubungan wajib diisi.';
    if (myFamily.length >= AppState.maxFamilyMembers) {
      return 'Maksimal ${AppState.maxFamilyMembers} anggota.';
    }
    myFamily.add(FamilyMember(
      id: _newId('f'),
      name: name.trim(),
      relation: relation.trim(),
      phone: phone.trim(),
    ));
    _changed();
    return null;
  }

  void removeFamilyMember(FamilyMember m) {
    if (m.id == _selfMemberId) return;
    myFamily.removeWhere((x) => x.id == m.id);
    _closeFamilyHelp(me, m, 'Anggota dihapus dari daftar keluarga.');
    _changed();
  }

  String _familyRef(AppUser owner, FamilyMember m) => 'fam:${owner.email}:${m.id}';

  /// Memperbarui status keselamatan. "Butuh bantuan" memberi tahu pengurus,
  /// petugas, dan relawan di wilayah serta membuat permintaan bantuan.
  void setSafety(FamilyMember m, SafetyStatus status) {
    final u = currentUser;
    if (u == null || m.status == status) return;
    m.status = status;
    m.updatedAt = DateTime.now();
    if (status == SafetyStatus.butuhBantuan) {
      final who = m.id == _selfMemberId ? u.name : '${m.name} (keluarga ${u.name})';
      for (final r in _respondersFor(u.areaId)) {
        if (r.email == u.email) continue;
        _notify(
          r,
          'Butuh bantuan: $who',
          '${Regions.shortName(u.areaId)}. Telepon: ${m.phone.isEmpty ? u.phone : m.phone}',
          'sos',
        );
      }
      final ref = _familyRef(u, m);
      final exists = helpRequests.any((h) => h.refKey == ref && h.isOpen);
      if (!exists) {
        helpRequests.insert(
          0,
          HelpRequest(
            id: _newId('h'),
            type: HelpType.evakuasi,
            title: 'Butuh bantuan: $who',
            description:
                'Status keselamatan diperbarui sendiri menjadi "Butuh bantuan". '
                'Kontak: ${m.phone.isEmpty ? u.phone : m.phone}.',
            areaId: u.areaId,
            createdByName: u.name,
            createdByEmail: u.email,
            createdAt: DateTime.now(),
            source: 'keluarga',
            refKey: ref,
            lat: u.hasLocation ? u.lastLat : null,
            lng: u.hasLocation ? u.lastLng : null,
          ),
        );
      }
    } else {
      _closeFamilyHelp(u, m, 'Status diperbarui menjadi "${status.label}".');
    }
    _changed();
  }

  void _closeFamilyHelp(AppUser owner, FamilyMember m, String note) {
    final ref = _familyRef(owner, m);
    for (final h in helpRequests) {
      if (h.refKey == ref && h.isOpen) {
        h.status = HelpStatus.selesai;
        h.doneAt = DateTime.now();
        h.doneNote = note;
      }
    }
  }

  /// "Kami semua aman": menandai seluruh anggota aman sekaligus.
  void setAllSafe() {
    for (final m in [...myFamily]) {
      setSafety(m, SafetyStatus.aman);
    }
  }

  /// Rumah tangga di wilayah pengurus yang perlu perhatian (butuh bantuan
  /// atau belum diketahui), yang butuh bantuan lebih dulu.
  List<HouseholdSafety> get householdsInMyArea {
    final u = currentUser;
    if (u == null || !isResponder) return [];
    final area = myAuthorityArea;
    final out = <HouseholdSafety>[];
    for (final owner in users) {
      if (!Regions.isWithin(owner.areaId, area)) continue;
      final list = _family[owner.email];
      if (list == null || list.isEmpty) continue;
      out.add(HouseholdSafety(owner, List<FamilyMember>.of(list)));
    }
    out.sort((a, b) {
      final c = b.needHelp.compareTo(a.needHelp);
      return c != 0 ? c : b.unknown.compareTo(a.unknown);
    });
    return out;
  }

  SafetyTotals get areaSafetyTotals {
    var safe = 0, need = 0, unknown = 0;
    for (final h in householdsInMyArea) {
      safe += h.safe;
      need += h.needHelp;
      unknown += h.unknown;
    }
    final area = currentUser == null ? null : myAuthorityArea;
    final reported = {for (final h in householdsInMyArea) h.owner.email};
    final notReported = area == null
        ? 0
        : users
            .where((x) =>
                x.role == UserRole.warga &&
                _reachable(x) &&
                Regions.isWithin(x.areaId, area) &&
                !reported.contains(x.email))
            .length;
    return SafetyTotals(safe, need, unknown, notReported);
  }

  // --------------------------------------------------- orang hilang

  bool _sameCity(String a, String b) {
    final ka = Regions.ancestorAtLevel(a, RegionLevel.kota);
    final kb = Regions.ancestorAtLevel(b, RegionLevel.kota);
    if (ka == null || kb == null) return a == b;
    return ka == kb;
  }

  /// Entri orang hilang di kota pengguna: yang masih dicari lebih dulu.
  List<MissingPerson> get missingForMe {
    final u = currentUser;
    if (u == null) return [];
    final out = missingPersons.where((p) => _sameCity(u.areaId, p.areaId)).toList();
    out.sort((a, b) {
      if (a.status != b.status) return a.status == MissingStatus.dicari ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return out;
  }

  String? addMissing({
    required String name,
    required String description,
    required String lastSeen,
    required String contactName,
    required String contactPhone,
    int? age,
    String? photoPath,
  }) {
    final u = currentUser;
    if (u == null) return 'Silakan masuk terlebih dahulu';
    if (name.trim().isEmpty) return 'Nama wajib diisi.';
    if (age != null && (age < 0 || age > 120)) return 'Usia tidak valid.';
    if (description.trim().length < 10) {
      return 'Tulis ciri-ciri minimal 10 karakter (pakaian, tinggi, ciri khusus).';
    }
    if (lastSeen.trim().isEmpty) return 'Isi tempat terakhir terlihat.';
    if (contactPhone.trim().replaceAll(RegExp(r'[^0-9]'), '').length < 6) {
      return 'Nomor kontak tidak valid.';
    }
    final p = MissingPerson(
      id: _newId('m'),
      name: name.trim(),
      age: age,
      description: description.trim(),
      lastSeen: lastSeen.trim(),
      areaId: u.areaId,
      reporterEmail: u.email,
      reporterName: u.name,
      contactName: contactName.trim().isEmpty ? u.name : contactName.trim(),
      contactPhone: contactPhone.trim(),
      createdAt: DateTime.now(),
      photoPath: photoPath,
    );
    missingPersons.insert(0, p);
    for (final r in _respondersFor(u.areaId)) {
      if (r.email == u.email) continue;
      _notify(
        r,
        'Orang hilang: ${p.name}',
        '${p.lastSeen} (${Regions.shortName(u.areaId)})',
        'alert',
      );
    }
    _changed();
    return null;
  }

  bool canManageMissing(MissingPerson p) {
    final u = currentUser;
    if (u == null) return false;
    if (p.reporterEmail == u.email) return true;
    return isResponder && Regions.isWithin(p.areaId, myAuthorityArea);
  }

  String? markFound(MissingPerson p, String note) {
    if (!canManageMissing(p)) return 'Anda tidak berwenang mengubah entri ini.';
    if (p.status == MissingStatus.ditemukan) return 'Sudah ditandai ditemukan.';
    p.status = MissingStatus.ditemukan;
    p.foundAt = DateTime.now();
    p.foundNote = note.trim().isEmpty ? null : note.trim();
    final owner = userByEmail(p.reporterEmail);
    if (owner != null && owner.email != me.email) {
      _notify(owner, 'Orang hilang ditemukan', '${p.name} ditandai ditemukan.', 'info');
    }
    _changed();
    return null;
  }

  // ------------------------------------------------------ posko

  /// Posko yang wilayahnya mencakup [areaId].
  List<EvacuationPoint> evacuationFor(String areaId) =>
      evacuationPoints.where((p) => Regions.isWithin(areaId, p.areaId)).toList();

  /// Posko di kota pengguna. Diurutkan dari yang terdekat bila [from] diketahui,
  /// jika tidak, posko di kelurahan pengguna lebih dulu.
  List<EvacuationPoint> poskoNearMe({GeoPoint? from}) {
    final u = currentUser;
    if (u == null) return [];
    final out = evacuationPoints
        .where((p) => _sameCity(u.areaId, p.areaId))
        .toList();
    double? dist(EvacuationPoint p) => from == null || !p.hasCoordinates
        ? null
        : haversineM(from.lat, from.lng, p.lat!, p.lng!);
    out.sort((a, b) {
      final da = dist(a), db = dist(b);
      if (da != null && db != null) return da.compareTo(db);
      if (da != null) return -1;
      if (db != null) return 1;
      final ha = Regions.isWithin(u.areaId, a.areaId) ? 0 : 1;
      final hb = Regions.isWithin(u.areaId, b.areaId) ? 0 : 1;
      final c = ha.compareTo(hb);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return out;
  }

  /// Mengubah daya tampung, jumlah pengungsi, stok, dan buka/tutup: pengurus,
  /// petugas, dan relawan di wilayah posko.
  bool canManagePosko(EvacuationPoint p) =>
      currentUser != null && isResponder && _overlaps(p.areaId, myAuthorityArea);

  /// Mendaftarkan posko baru: Ketua RT, Petugas, Admin.
  bool get canAddPosko => isKetuaRt || isPetugas || isAdmin;

  String? addPosko({
    required String name,
    required String address,
    required int capacity,
    String? phone,
    double? lat,
    double? lng,
  }) {
    final u = currentUser;
    if (u == null || !canAddPosko) {
      return 'Hanya pengurus atau petugas yang boleh menambah posko.';
    }
    if (name.trim().isEmpty) return 'Nama posko wajib diisi.';
    if (capacity < 1 || capacity > 100000) return 'Daya tampung tidak valid.';
    final area = isAdmin
        ? u.areaId
        : (Regions.ancestorAtLevel(u.areaId, RegionLevel.kelurahan) ?? u.areaId);
    final id = _newId('e');
    final hasPoint = isValidCoord(lat, lng);
    evacuationPoints.add(EvacuationPoint(
      id: id,
      name: name.trim(),
      address: address.trim(),
      areaId: area,
      capacity: capacity,
      phone: phone == null || phone.trim().isEmpty ? null : phone.trim(),
      lat: hasPoint ? lat : null,
      lng: hasPoint ? lng : null,
      logistics: [
        for (var i = 0; i < kLogisticTemplates.length; i++)
          LogisticItem(
            id: '$id-l$i',
            name: kLogisticTemplates[i].name,
            unit: kLogisticTemplates[i].unit,
            stock: 0,
            minStock: kLogisticTemplates[i].minStock,
          ),
      ],
    ));
    _changed();
    return null;
  }

  String? setOccupants(EvacuationPoint p, int count) {
    if (!canManagePosko(p)) return 'Anda tidak berwenang mengubah posko ini.';
    if (count < 0) return 'Jumlah pengungsi tidak boleh negatif.';
    final before = p.state;
    p.occupants = count;
    p.updatedAt = DateTime.now();
    if (before != PoskoState.penuh && p.state == PoskoState.penuh) {
      for (final r in _respondersFor(p.areaId)) {
        if (r.email == me.email) continue;
        _notify(
          r,
          'Posko penuh: ${p.name}',
          'Daya tampung ${p.capacity} orang terpenuhi. Siapkan posko lain.',
          'alert',
        );
      }
    }
    _changed();
    return null;
  }

  String? adjustOccupants(EvacuationPoint p, int delta) {
    final next = p.occupants + delta;
    return setOccupants(p, next < 0 ? 0 : next);
  }

  String? setPoskoOpen(EvacuationPoint p, bool open) {
    if (!canManagePosko(p)) return 'Anda tidak berwenang mengubah posko ini.';
    p.open = open;
    p.updatedAt = DateTime.now();
    _changed();
    return null;
  }

  String? setCapacity(EvacuationPoint p, int capacity) {
    if (!canManagePosko(p)) return 'Anda tidak berwenang mengubah posko ini.';
    if (capacity < 1 || capacity > 100000) return 'Daya tampung tidak valid.';
    p.capacity = capacity;
    p.updatedAt = DateTime.now();
    _changed();
    return null;
  }

  // ---------------------------------------------------------- logistik

  /// Mengubah stok sebesar [delta] (negatif = terpakai). Stok yang menipis
  /// memberi tahu pengurus dan membuat permintaan bantuan logistik untuk relawan.
  String? adjustStock(EvacuationPoint p, LogisticItem item, int delta) =>
      setStock(p, item, item.stock + delta);

  String? setStock(EvacuationPoint p, LogisticItem item, int value) {
    if (!canManagePosko(p)) return 'Anda tidak berwenang mengubah stok posko ini.';
    if (!p.logistics.any((i) => i.id == item.id)) return 'Barang tidak ditemukan.';
    final wasLow = item.low;
    item.stock = value < 0 ? 0 : value;
    p.updatedAt = DateTime.now();
    if (item.low && !wasLow) _onLowStock(p, item);
    _changed();
    return null;
  }

  void _onLowStock(EvacuationPoint p, LogisticItem item) {
    for (final r in _respondersFor(p.areaId)) {
      if (r.email == me.email) continue;
      _notify(
        r,
        'Stok menipis: ${item.name}',
        '${p.name} tersisa ${item.stock} ${item.unit}.',
        'alert',
      );
    }
    final ref = 'stok:${item.id}';
    if (helpRequests.any((h) => h.refKey == ref && h.isOpen)) return;
    helpRequests.insert(
      0,
      HelpRequest(
        id: _newId('h'),
        type: HelpType.logistik,
        title: 'Kirim ${item.name} ke ${p.name}',
        description:
            'Stok tersisa ${item.stock} ${item.unit} (batas minimal ${item.minStock}).',
        areaId: p.areaId,
        createdByName: me.name,
        createdByEmail: me.email,
        createdAt: DateTime.now(),
        source: 'logistik',
        refKey: ref,
        lat: p.lat,
        lng: p.lng,
      ),
    );
  }

  // -------------------------------------------------- relawan / bantuan

  /// Permintaan bantuan yang terlihat: pengawas melihat yang di wilayahnya,
  /// warga hanya yang dibuatnya sendiri. Yang masih terbuka lebih dulu.
  List<HelpRequest> get visibleHelpRequests {
    final u = currentUser;
    if (u == null) return [];
    final area = myAuthorityArea;
    final out = helpRequests.where((h) {
      if (h.createdByEmail == u.email) return true;
      return isResponder && Regions.isWithin(h.areaId, area);
    }).toList();
    out.sort((a, b) {
      if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return out;
  }

  int get openHelpCount =>
      visibleHelpRequests.where((h) => h.status == HelpStatus.terbuka).length;

  String? createHelpRequest({
    required HelpType type,
    required String title,
    required String description,
    double? lat,
    double? lng,
  }) {
    final u = currentUser;
    if (u == null || !isResponder) {
      return 'Hanya pengurus, petugas, atau relawan yang boleh membuat permintaan.';
    }
    if (title.trim().isEmpty) return 'Judul wajib diisi.';
    final hasPoint = isValidCoord(lat, lng);
    helpRequests.insert(
      0,
      HelpRequest(
        id: _newId('h'),
        type: type,
        title: title.trim(),
        description: description.trim(),
        areaId: u.areaId,
        createdByName: u.name,
        createdByEmail: u.email,
        createdAt: DateTime.now(),
        lat: hasPoint ? lat : null,
        lng: hasPoint ? lng : null,
      ),
    );
    for (final r in users) {
      if (r.role != UserRole.relawan || !r.approved || r.email == u.email) continue;
      if (!Regions.isWithin(u.areaId, authorityAreaOf(r))) continue;
      _notify(r, 'Butuh relawan: ${title.trim()}', type.label, 'alert');
    }
    _changed();
    return null;
  }

  bool canClaimHelp(HelpRequest h) =>
      currentUser != null &&
      (isRelawan || isPetugas) &&
      h.status == HelpStatus.terbuka &&
      Regions.isWithin(h.areaId, myAuthorityArea);

  String? claimHelp(HelpRequest h) {
    final u = currentUser;
    if (u == null || !canClaimHelp(h)) {
      return 'Permintaan ini tidak bisa Anda ambil.';
    }
    h.status = HelpStatus.diambil;
    h.claimedByEmail = u.email;
    h.claimedByName = u.name;
    h.claimedAt = DateTime.now();
    final creator = userByEmail(h.createdByEmail);
    if (creator != null && creator.email != u.email) {
      _notify(
        creator,
        'Bantuan diambil',
        '${u.name} (${u.role.label}) menangani: ${h.title}',
        'info',
      );
    }
    _changed();
    return null;
  }

  /// Relawan melepas kembali permintaan yang tidak sanggup dikerjakan.
  String? releaseHelp(HelpRequest h) {
    final u = currentUser;
    if (u == null || h.claimedByEmail != u.email || h.status != HelpStatus.diambil) {
      return 'Hanya penanggung jawab yang bisa melepas permintaan ini.';
    }
    h.status = HelpStatus.terbuka;
    h.claimedByEmail = null;
    h.claimedByName = null;
    h.claimedAt = null;
    _changed();
    return null;
  }

  bool canCompleteHelp(HelpRequest h) {
    final u = currentUser;
    if (u == null || !h.isOpen) return false;
    if (h.claimedByEmail == u.email) return true;
    return isModerator && Regions.isWithin(h.areaId, myAuthorityArea);
  }

  String? completeHelp(HelpRequest h, String note) {
    final u = currentUser;
    if (u == null || !canCompleteHelp(h)) {
      return 'Anda tidak berwenang menyelesaikan permintaan ini.';
    }
    h.status = HelpStatus.selesai;
    h.doneAt = DateTime.now();
    h.doneNote = note.trim().isEmpty ? null : note.trim();
    final creator = userByEmail(h.createdByEmail);
    if (creator != null && creator.email != u.email) {
      _notify(creator, 'Bantuan selesai', h.title, 'info');
    }
    _changed();
    return null;
  }
}
