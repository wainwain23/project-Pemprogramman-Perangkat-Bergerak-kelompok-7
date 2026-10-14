import '../models.dart';
import '../safety_models.dart';
import 'regions.dart';

DateTime _ago({int minutes = 0, int hours = 0, int days = 0}) => DateTime.now()
    .subtract(Duration(minutes: minutes, hours: hours, days: days));

/// Akun demo (sandi semuanya: 123456).
List<AppUser> buildSeedUsers() => [
      AppUser(
        name: 'Rina',
        email: 'warga@demo.id',
        phone: '0812-0000-1111',
        password: '123456',
        role: UserRole.warga,
        areaId: RegionIds.rtSukagalih0503,
      ),
      AppUser(
        name: 'Pak Hasan',
        email: 'rt@demo.id',
        phone: '0812-0000-0001',
        password: '123456',
        role: UserRole.ketuaRt,
        areaId: RegionIds.rtSukagalih0503,
      ),
      AppUser(
        name: 'Petugas Dani',
        email: 'petugas@demo.id',
        phone: '0812-0000-2222',
        password: '123456',
        role: UserRole.petugas,
        areaId: RegionIds.rtSukagalih0503,
      ),
      AppUser(
        name: 'Relawan Maya',
        email: 'relawan@demo.id',
        phone: '0812-0000-3333',
        password: '123456',
        role: UserRole.relawan,
        areaId: RegionIds.rtSukagalih0503,
      ),
      AppUser(
        name: 'Admin Kelurahan',
        email: 'admin@demo.id',
        phone: '0812-0000-9999',
        password: '123456',
        role: UserRole.admin,
        areaId: RegionIds.kelSukagalih,
      ),
      AppUser(
        name: 'Super Admin',
        email: 'super@demo.id',
        phone: '0812-0000-0000',
        password: '123456',
        role: UserRole.superAdmin,
        areaId: Regions.rootId,
      ),
      // Menunggu persetujuan admin wilayah.
      AppUser(
        name: 'Bu Sari',
        email: 'sari@demo.id',
        phone: '0812-0000-4444',
        password: '123456',
        role: UserRole.ketuaRt,
        areaId: RegionIds.rtSukagalih0504,
        status: AccountStatus.menunggu,
      ),
      AppUser(
        name: 'Joni Petugas',
        email: 'joni@demo.id',
        phone: '0812-0000-5555',
        password: '123456',
        role: UserRole.petugas,
        areaId: RegionIds.rtSukagalih0504,
        status: AccountStatus.menunggu,
      ),
      // Menunggu persetujuan Ketua RT 03 (atau admin).
      AppUser(
        name: 'Relawan Tono',
        email: 'tono@demo.id',
        phone: '0812-0000-6666',
        password: '123456',
        role: UserRole.relawan,
        areaId: RegionIds.rtSukagalih0503,
        status: AccountStatus.menunggu,
      ),
    ];

Map<String, List<FamilyMember>> buildSeedFamilies() => {
      'warga@demo.id': [
        FamilyMember(
          id: 'f1',
          name: 'Bu Ani',
          relation: 'Ibu',
          phone: '0812-0000-7001',
          status: SafetyStatus.aman,
          updatedAt: _ago(hours: 3),
        ),
        FamilyMember(
          id: 'f2',
          name: 'Dika',
          relation: 'Adik',
          phone: '0812-0000-7002',
        ),
      ],
    };

TimelineEvent _ev(
  DateTime at,
  String actor,
  String role,
  String action, {
  ReportStatus? status,
  String? note,
}) =>
    TimelineEvent(
      at: at,
      actor: actor,
      role: role,
      action: action,
      status: status,
      note: note,
    );

List<Report> buildSeedReports() => [
      Report(
        id: 'r1',
        authorName: 'Rina',
        authorEmail: 'warga@demo.id',
        category: 'Banjir',
        description: 'Air setinggi lutut di Gang 3, arus mulai deras.',
        areaId: RegionIds.rtSukagalih0503,
        location: 'Gang 3, dekat warung Bu Ani',
        createdAt: _ago(minutes: 10),
        hasPhoto: true,
        lat: -6.8868,
        lng: 107.5919,
        accuracyM: 8,
        severity: Severity.bahaya,
        status: ReportStatus.diproses,
        confirmations: 4,
        verifiedAt: _ago(minutes: 6),
        processedAt: _ago(minutes: 4),
        assigneeEmail: 'petugas@demo.id',
        assigneeName: 'Petugas Dani',
        assignedAt: _ago(minutes: 5),
        comments: [
          ReportComment(
            author: 'Pak Hasan (Ketua RT)',
            text: 'Terverifikasi. Warga dimohon menjauh dari Gang 3.',
            createdAt: _ago(minutes: 6),
            official: true,
          ),
        ],
        timeline: [
          _ev(_ago(minutes: 10), 'Rina', 'Warga', 'Laporan dibuat',
              status: ReportStatus.menunggu),
          _ev(_ago(minutes: 6), 'Pak Hasan', 'Ketua RT', 'Diverifikasi',
              status: ReportStatus.terverifikasi, note: 'Tingkat: Bahaya'),
          _ev(_ago(minutes: 5), 'Pak Hasan', 'Ketua RT',
              'Ditugaskan ke Petugas Dani'),
          _ev(_ago(minutes: 4), 'Petugas Dani', 'Petugas Lapangan',
              'Mulai ditangani',
              status: ReportStatus.diproses),
        ],
      ),
      Report(
        id: 'r2',
        authorName: 'Budi',
        authorEmail: 'budi@demo.id',
        category: 'Longsor',
        description: 'Tanah di tebing belakang masjid mulai retak.',
        areaId: RegionIds.rtSukagalih0504,
        location: 'Belakang Masjid Al-Hidayah',
        createdAt: _ago(hours: 2),
        lat: -6.8851,
        lng: 107.5948,
        accuracyM: 12,
        severity: Severity.waspada,
        status: ReportStatus.terverifikasi,
        confirmations: 3,
        verifiedAt: _ago(hours: 1),
        timeline: [
          _ev(_ago(hours: 2), 'Budi', 'Warga', 'Laporan dibuat',
              status: ReportStatus.menunggu),
          _ev(_ago(hours: 1), 'Admin Kelurahan', 'Admin Wilayah', 'Diverifikasi',
              status: ReportStatus.terverifikasi, note: 'Tingkat: Waspada'),
        ],
      ),
      Report(
        id: 'r3',
        authorName: 'Dewi',
        authorEmail: 'dewi@demo.id',
        category: 'Jalan rusak',
        description: 'Lubang besar di Jl. Melati, berbahaya untuk motor.',
        areaId: RegionIds.rtSukagalih0503,
        location: 'Jl. Melati No. 12',
        createdAt: _ago(hours: 5),
        lat: -6.8893,
        lng: 107.5906,
        accuracyM: 15,
        timeline: [
          _ev(_ago(hours: 5), 'Dewi', 'Warga', 'Laporan dibuat',
              status: ReportStatus.menunggu),
        ],
      ),
      Report(
        id: 'r4',
        authorName: 'Andi',
        authorEmail: 'andi@demo.id',
        category: 'Lampu mati',
        description: 'Lampu jalan di pertigaan mati sejak tiga hari lalu.',
        areaId: RegionIds.rtSukagalih0503,
        location: 'Pertigaan Jl. Melati',
        createdAt: _ago(days: 1),
        lat: -6.8884,
        lng: 107.5937,
        accuracyM: 10,
        confirmations: 2,
        timeline: [
          _ev(_ago(days: 1), 'Andi', 'Warga', 'Laporan dibuat',
              status: ReportStatus.menunggu),
        ],
      ),
      Report(
        id: 'r5',
        authorName: 'Joko',
        authorEmail: 'joko@demo.id',
        category: 'Sampah',
        description: 'Tumpukan sampah di tepi sungai belum diangkut.',
        areaId: RegionIds.rtSukagalih0601,
        location: 'Tepi sungai RW 06',
        createdAt: _ago(days: 2),
        lat: -6.8902,
        lng: 107.5911,
        accuracyM: 20,
        severity: Severity.info,
        status: ReportStatus.selesai,
        confirmations: 2,
        verifiedAt: _ago(days: 2),
        resolvedAt: _ago(days: 1),
        timeline: [
          _ev(_ago(days: 2), 'Joko', 'Warga', 'Laporan dibuat',
              status: ReportStatus.menunggu),
          _ev(_ago(days: 2), 'Admin Kelurahan', 'Admin Wilayah', 'Diverifikasi',
              status: ReportStatus.terverifikasi),
          _ev(_ago(days: 1), 'Admin Kelurahan', 'Admin Wilayah',
              'Ditandai selesai',
              status: ReportStatus.selesai),
        ],
      ),
      Report(
        id: 'r6',
        authorName: 'Lina',
        authorEmail: 'lina@demo.id',
        category: 'Pohon tumbang',
        description: 'Pohon besar menutup separuh jalan.',
        areaId: RegionIds.rtSenayan0102,
        location: 'Jl. Asia Afrika (contoh)',
        createdAt: _ago(hours: 3),
        lat: -6.2268,
        lng: 106.8002,
        accuracyM: 9,
        severity: Severity.waspada,
        status: ReportStatus.terverifikasi,
        confirmations: 3,
        verifiedAt: _ago(hours: 2),
        timeline: [
          _ev(_ago(hours: 3), 'Lina', 'Warga', 'Laporan dibuat',
              status: ReportStatus.menunggu),
          _ev(_ago(hours: 2), 'Sistem', 'Sistem',
              'Terverifikasi otomatis (3 konfirmasi warga)',
              status: ReportStatus.terverifikasi),
        ],
      ),
      Report(
        id: 'r7',
        authorName: 'Eko',
        authorEmail: 'eko@demo.id',
        category: 'Banjir',
        description: 'Genangan setinggi mata kaki di depan balai RW.',
        areaId: RegionIds.rtAirlangga0201,
        location: 'Depan balai RW 02',
        createdAt: _ago(hours: 1),
        lat: -7.2676,
        lng: 112.7586,
        accuracyM: 11,
        severity: Severity.waspada,
        status: ReportStatus.terverifikasi,
        confirmations: 3,
        verifiedAt: _ago(minutes: 40),
        timeline: [
          _ev(_ago(hours: 1), 'Eko', 'Warga', 'Laporan dibuat',
              status: ReportStatus.menunggu),
          _ev(_ago(minutes: 40), 'Sistem', 'Sistem',
              'Terverifikasi otomatis (3 konfirmasi warga)',
              status: ReportStatus.terverifikasi),
        ],
      ),
    ];

List<Announcement> buildSeedAnnouncements() => [
      Announcement(
        id: 'a1',
        areaId: RegionIds.kotaBandung,
        tag: 'Penting',
        title: 'Imbauan musim hujan',
        body:
            'Bersihkan saluran air di sekitar rumah dan siapkan tas siaga bencana berisi dokumen, obat, dan senter.',
        author: 'Admin Kota (contoh)',
        createdAt: _ago(days: 1),
        pinned: true,
      ),
      Announcement(
        id: 'a7',
        areaId: RegionIds.kelSukagalih,
        tag: 'Evakuasi',
        title: 'Jalur dan titik kumpul evakuasi banjir',
        body:
            'Bila air naik, warga RT 03-06 menuju Masjid Al-Hidayah lewat Jl. Melati. '
            'Lansia dan anak diutamakan. Hindari Gang 3. Bawa dokumen dan obat pribadi.',
        author: 'Admin Kelurahan (Admin Wilayah)',
        createdAt: _ago(hours: 1),
        pinned: true,
      ),
      Announcement(
        id: 'a2',
        areaId: RegionIds.rtSukagalih0503,
        tag: 'Penting',
        title: 'Kerja bakti bersihkan selokan',
        body:
            'Minggu pukul 07.00 di lapangan RT. Mohon membawa alat kebersihan masing-masing.',
        author: 'Pak Hasan (Ketua RT)',
        createdAt: _ago(hours: 2),
      ),
      Announcement(
        id: 'a3',
        areaId: RegionIds.rtSukagalih0503,
        tag: 'Iuran',
        title: 'Iuran keamanan bulan ini',
        body:
            'Terkumpul 42 dari 55 KK. Pembayaran ke bendahara RT paling lambat tanggal 10.',
        author: 'Pak Hasan (Ketua RT)',
        createdAt: _ago(hours: 5),
      ),
      Announcement(
        id: 'a4',
        areaId: RegionIds.rwSukagalih05,
        tag: 'Kegiatan',
        title: 'Posyandu balita dan lansia',
        body: 'Setiap tanggal 15 pukul 09.00 di balai RW 05.',
        author: 'Pengurus RW 05',
        createdAt: _ago(days: 2),
      ),
      Announcement(
        id: 'a5',
        areaId: RegionIds.kelSukagalih,
        tag: 'Info',
        title: 'Jadwal angkut sampah',
        body:
            'Setiap Senin dan Kamis pagi. Letakkan sampah di depan rumah sebelum pukul 06.30.',
        author: 'Admin Kelurahan (Admin Wilayah)',
        createdAt: _ago(days: 1, hours: 3),
      ),
      Announcement(
        id: 'a6',
        areaId: RegionIds.kotaJaksel,
        tag: 'Info',
        title: 'Latihan evakuasi mandiri',
        body: 'Simulasi evakuasi bencana akan dilakukan akhir bulan ini.',
        author: 'Admin Kota (contoh)',
        createdAt: _ago(days: 2),
      ),
    ];

List<LogisticItem> _stock(
  String prefix, {
  required int air,
  required int tenda,
  required int obat,
  required int makanan,
  required int selimut,
}) {
  final amounts = [air, tenda, obat, makanan, selimut];
  return [
    for (var i = 0; i < kLogisticTemplates.length; i++)
      LogisticItem(
        id: '$prefix-l$i',
        name: kLogisticTemplates[i].name,
        unit: kLogisticTemplates[i].unit,
        stock: amounts[i],
        minStock: kLogisticTemplates[i].minStock,
      ),
  ];
}

/// Posko contoh. Nomor telepon dan alamat hanya contoh.
List<EvacuationPoint> buildSeedEvacuation() => [
      EvacuationPoint(
        id: 'e1',
        name: 'Masjid Al-Hidayah',
        address: 'Jl. Melati (contoh)',
        areaId: RegionIds.kelSukagalih,
        capacity: 150,
        occupants: 32,
        lat: -6.8858,
        lng: 107.5952,
        phone: '0812-0000-8001',
        logistics: _stock('e1',
            air: 380, tenda: 6, obat: 14, makanan: 70, selimut: 40),
      ),
      EvacuationPoint(
        id: 'e2',
        name: 'Aula Kelurahan Sukagalih',
        address: 'Kantor kelurahan (contoh)',
        areaId: RegionIds.kelSukagalih,
        capacity: 300,
        occupants: 248,
        lat: -6.8897,
        lng: 107.5903,
        phone: '0812-0000-8002',
        logistics: _stock('e2',
            air: 90, tenda: 3, obat: 4, makanan: 55, selimut: 25),
      ),
      EvacuationPoint(
        id: 'e3',
        name: 'Balai Warga Senayan',
        address: 'Senayan (contoh)',
        areaId: RegionIds.kelSenayan,
        capacity: 200,
        occupants: 0,
        lat: -6.2280,
        lng: 106.7984,
        phone: '0812-0000-8003',
        logistics: _stock('e3',
            air: 500, tenda: 10, obat: 20, makanan: 100, selimut: 60),
      ),
      EvacuationPoint(
        id: 'e4',
        name: 'Balai RW 02 Airlangga',
        address: 'Airlangga (contoh)',
        areaId: RegionIds.kelAirlangga,
        capacity: 120,
        occupants: 10,
        lat: -7.2688,
        lng: 112.7571,
        phone: '0812-0000-8004',
        logistics: _stock('e4',
            air: 300, tenda: 4, obat: 9, makanan: 40, selimut: 20),
      ),
      EvacuationPoint(
        id: 'e5',
        name: 'Aula Kelurahan Babura',
        address: 'Babura (contoh)',
        areaId: RegionIds.kelBabura,
        capacity: 250,
        occupants: 0,
        lat: 3.5792,
        lng: 98.6571,
        phone: '0812-0000-8005',
        logistics: _stock('e5',
            air: 450, tenda: 8, obat: 18, makanan: 90, selimut: 50),
      ),
    ];

/// Nomor darurat nasional. Periksa kembali nomor di daerah masing-masing.
List<EmergencyContact> buildNationalContacts() => const [
      EmergencyContact('Darurat terpadu', '112', national: true),
      EmergencyContact('Polisi', '110', national: true),
      EmergencyContact('Pemadam kebakaran', '113', national: true),
      EmergencyContact('Ambulans / gawat darurat', '119', national: true),
      EmergencyContact('SAR / Basarnas', '115', national: true),
      EmergencyContact('PLN (gangguan listrik)', '123', national: true),
    ];

List<EmergencyContact> buildDefaultPersonalContacts() => const [
      EmergencyContact('Ketua RT (contoh)', '0812-0000-0001'),
      EmergencyContact('Keluarga (contoh)', '0812-0000-0003'),
    ];

/// Nomor penting setempat. SEMUA nomor di sini hanya contoh dan harus diganti
/// pengurus wilayah dengan nomor resmi.
List<LocalContact> buildSeedLocalContacts() => const [
      LocalContact(
        id: 'lc1',
        name: 'Rumah Sakit terdekat (contoh)',
        phone: '022-0000-0001',
        kind: LocalContactKind.rumahSakit,
        areaId: RegionIds.kotaBandung,
        address: 'Isi dengan RS rujukan resmi',
      ),
      LocalContact(
        id: 'lc2',
        name: 'Puskesmas Sukajadi (contoh)',
        phone: '022-0000-0002',
        kind: LocalContactKind.puskesmas,
        areaId: RegionIds.kecSukajadi,
      ),
      LocalContact(
        id: 'lc3',
        name: 'BPBD Kota Bandung (contoh)',
        phone: '022-0000-0003',
        kind: LocalContactKind.bpbd,
        areaId: RegionIds.kotaBandung,
      ),
      LocalContact(
        id: 'lc4',
        name: 'Rumah Sakit terdekat (contoh)',
        phone: '021-0000-0004',
        kind: LocalContactKind.rumahSakit,
        areaId: RegionIds.kotaJaksel,
      ),
    ];

List<MissingPerson> buildSeedMissing() => [
      MissingPerson(
        id: 'm1',
        name: 'Pak Ujang (contoh)',
        age: 68,
        description:
            'Laki-laki, rambut putih, memakai sarung kotak-kotak dan peci hitam. Mudah lupa.',
        lastSeen: 'Terakhir terlihat di Gang 3 saat air naik',
        areaId: RegionIds.rtSukagalih0503,
        reporterEmail: 'rt@demo.id',
        reporterName: 'Pak Hasan',
        contactName: 'Pak Hasan (Ketua RT)',
        contactPhone: '0812-0000-0001',
        createdAt: _ago(minutes: 30),
      ),
    ];

List<HelpRequest> buildSeedHelpRequests() => [
      HelpRequest(
        id: 'h1',
        type: HelpType.evakuasi,
        title: 'Bantu evakuasi lansia di Gang 3',
        description:
            'Dua lansia di rumah dekat warung Bu Ani butuh dipapah ke Masjid Al-Hidayah.',
        areaId: RegionIds.rtSukagalih0503,
        createdByName: 'Pak Hasan',
        createdByEmail: 'rt@demo.id',
        createdAt: _ago(minutes: 8),
        lat: -6.8868,
        lng: 107.5919,
      ),
    ];

class GuideItem {
  final String title;
  final String subtitle;
  final List<String> before;
  final List<String> during;
  final List<String> after;
  const GuideItem(
      this.title, this.subtitle, this.before, this.during, this.after);
}

const List<GuideItem> kGuides = [
  GuideItem(
    'Banjir',
    'Genangan dan luapan sungai',
    [
      'Kenali titik evakuasi dan jalur menuju tempat tinggi.',
      'Siapkan tas siaga: dokumen, obat, senter, makanan.',
      'Bersihkan saluran air di sekitar rumah.',
    ],
    [
      'Matikan listrik dan gas bila air mulai masuk.',
      'Pindah ke tempat yang lebih tinggi.',
      'Jangan menerjang arus air, sekalipun terlihat dangkal.',
    ],
    [
      'Jangan menyalakan listrik sebelum diperiksa.',
      'Buang makanan yang terendam air banjir.',
      'Laporkan kerusakan lewat aplikasi.',
    ],
  ),
  GuideItem(
    'Gempa bumi',
    'Guncangan kuat',
    [
      'Pastikan lemari dan rak tinggi tidak mudah roboh.',
      'Tentukan tempat berlindung di tiap ruangan.',
    ],
    [
      'Merunduk, berlindung di bawah meja kokoh, dan berpegangan.',
      'Jauhi kaca, lemari, dan benda yang bisa jatuh.',
      'Di luar ruangan, menjauh dari gedung, tiang, dan pohon.',
    ],
    [
      'Keluar ke ruang terbuka bila bangunan rusak.',
      'Waspada gempa susulan.',
      'Dekat pantai: segera menuju tempat tinggi bila guncangan kuat atau lama.',
    ],
  ),
  GuideItem(
    'Longsor',
    'Tanah bergerak di lereng',
    [
      'Perhatikan retakan tanah dan air keruh di lereng.',
      'Jangan membangun atau menebang pohon sembarangan di lereng.',
    ],
    [
      'Segera menjauh dari lereng, tegak lurus arah luncuran.',
      'Peringatkan tetangga dan hubungi Ketua RT.',
    ],
    [
      'Jangan kembali sebelum area dinyatakan aman.',
      'Waspada longsor susulan.',
    ],
  ),
  GuideItem(
    'Kebakaran',
    'Api di rumah atau lingkungan',
    [
      'Pasang alat pemadam ringan dan kenali jalur keluar.',
      'Jangan membebani stopkontak.',
    ],
    [
      'Hubungi 113 dan teriaki tetangga.',
      'Merunduk di bawah asap dan tutup hidung dengan kain basah.',
      'Jangan memakai lift.',
    ],
    [
      'Jangan masuk kembali sebelum petugas mengizinkan.',
      'Laporkan kejadian kepada pengurus RT.',
    ],
  ),
  GuideItem(
    'Tsunami',
    'Gelombang laut setelah gempa kuat',
    [
      'Kenali jalur dan tempat evakuasi tinggi bila tinggal di pesisir.',
      'Ikuti latihan evakuasi yang diadakan BPBD setempat.',
    ],
    [
      'Bila gempa kuat atau lama terasa di pantai, langsung menuju tempat tinggi tanpa menunggu peringatan.',
      'Jauhi pantai, muara, dan sungai besar.',
    ],
    [
      'Tetap di tempat tinggi sampai petugas menyatakan aman; gelombang bisa datang berkali-kali.',
    ],
  ),
  GuideItem(
    'Angin kencang',
    'Puting beliung dan badai',
    [
      'Pangkas dahan pohon yang rapuh di dekat rumah.',
      'Periksa atap dan benda yang mudah terbang.',
    ],
    [
      'Berlindung di dalam bangunan kokoh, jauhi jendela dan kaca.',
      'Jangan berteduh di bawah pohon atau dekat tiang.',
    ],
    [
      'Waspada kabel listrik putus dan pohon yang condong.',
      'Laporkan kerusakan lewat aplikasi.',
    ],
  ),
  GuideItem(
    'Erupsi gunung api',
    'Abu vulkanik dan awan panas',
    [
      'Kenali status gunung api dan zona bahaya dari PVMBG/BPBD.',
      'Siapkan masker, kacamata, dan tas siaga.',
    ],
    [
      'Ikuti perintah evakuasi, jangan mendekati zona bahaya.',
      'Pakai masker dan lindungi mata dari abu.',
    ],
    [
      'Bersihkan abu dari atap dengan hati-hati agar tidak runtuh.',
      'Jangan kembali ke zona bahaya sebelum dinyatakan aman.',
    ],
  ),
];
