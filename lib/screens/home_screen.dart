import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../geo.dart';
import '../models.dart';
import '../safety_models.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/sos_button.dart';
import '../widgets/weather_banner.dart';
import 'approvals_screen.dart';
import 'broadcast_screen.dart';
import 'family_screen.dart';
import 'help_screen.dart';
import 'info_screens.dart';
import 'missing_screen.dart';
import 'notifications_screen.dart';
import 'posko_screen.dart';
import 'report_detail_screen.dart';
import 'report_form_screen.dart';
import 'sos_monitor_screen.dart';
import 'tasks_screen.dart';

void _open(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

class HomeScreen extends StatelessWidget {
  final void Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  /// Mengirim SOS. Lokasi GPS diambil paling lama 4 detik; bila gagal dipakai
  /// lokasi terakhir yang diketahui. SOS tetap terkirim tanpa lokasi.
  Future<void> _sendSos(BuildContext context) async {
    final s = AppState.instance;
    snack(context, 'Mengirim SOS dan mengambil lokasi...');
    double? lat;
    double? lng;
    String note = '';
    try {
      final res =
          await LocationService.current().timeout(const Duration(seconds: 4));
      if (res.ok) {
        lat = res.fix!.lat;
        lng = res.fix!.lng;
      } else {
        note = res.message;
      }
    } catch (_) {
      note = 'Lokasi belum didapat tepat waktu.';
    }
    if (lat == null && s.me.hasLocation) {
      lat = s.me.lastLat;
      lng = s.me.lastLng;
      note = '$note Memakai lokasi terakhir yang diketahui.'.trim();
    }
    final e = s.triggerSos(lat: lat, lng: lng);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: kTeal, size: 48),
        title: const Text('SOS tercatat'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.viaSms
                    ? 'Anda sedang offline (simulasi). SOS akan diteruskan saat internet kembali.'
                    : 'SOS diteruskan ke pengurus, petugas, dan relawan di wilayah Anda lewat aplikasi.',
              ),
              const SizedBox(height: 8),
              Text(e.hasCoordinates
                  ? 'Lokasi terkirim: ${formatCoord(e.lat!, e.lng!)}'
                  : 'Lokasi GPS tidak tersedia.'),
              if (note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(note,
                      style: const TextStyle(fontSize: 12, color: kGray)),
                ),
              const SizedBox(height: 8),
              const Text(
                'Bila nyawa terancam, hubungi juga 112 (nomor darurat nasional). '
                'Pemberitahuan ke ponsel kontak darurat membutuhkan server/SMS gateway yang belum tersedia di versi ini.',
                style: TextStyle(fontSize: 12, color: kGray),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelSos(context);
            },
            child: const Text('Batalkan SOS'),
          ),
          TextButton(
            onPressed: () => callPhone(ctx, '112'),
            child: const Text('Telepon 112'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  /// Pembatalan SOS wajib disertai alasan (tercatat di riwayat SOS).
  Future<void> _cancelSos(BuildContext context) async {
    const reasons = [
      'Salah pencet',
      'Sudah aman',
      'Sudah ditangani warga/petugas',
    ];
    var picked = reasons.first;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Batalkan SOS'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pilih alasan pembatalan:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final r in reasons)
                    ChoiceChip(
                      label: Text(r),
                      selected: picked == r,
                      onSelected: (_) => setLocal(() => picked = r),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Kembali')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, picked),
                child: const Text('Batalkan SOS')),
          ],
        ),
      ),
    );
    if (reason == null) return;
    AppState.instance.cancelSos(reason);
    if (context.mounted) snack(context, 'SOS dibatalkan: $reason.');
  }

  void _showBroadcast(BuildContext context, EmergencyBroadcast b) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.cell_tower, color: severityColor(b.severity), size: 40),
        title: Text(b.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.message),
              const SizedBox(height: 10),
              Text(
                'Dari ${b.senderName} (${b.senderRole}) - ${dateTimeLabel(b.createdAt)}\n'
                'Wilayah: ${Regions.fullName(b.areaId)}',
                style: const TextStyle(fontSize: 12, color: kGray),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        final u = s.me;
        final kelReports = s.reportsInScope(ReportScope.kelurahan);
        final alerts = kelReports
            .where((r) =>
                (r.status == ReportStatus.terverifikasi ||
                    r.status == ReportStatus.diproses) &&
                r.severity != Severity.info)
            .take(2)
            .toList();
        final active = kelReports.where((r) => r.status.isActive).length;
        final verified = kelReports
            .where((r) => r.status == ReportStatus.terverifikasi)
            .length;
        final done =
            kelReports.where((r) => r.status == ReportStatus.selesai).length;
        final sos = s.activeSos;
        final since = DateTime.now().subtract(const Duration(hours: 24));
        final recentBroadcasts = s.receivedBroadcasts
            .where((b) => b.createdAt.isAfter(since))
            .take(2)
            .toList();
        final highlights = s.officialHighlights;
        final pendingApprovals = s.pendingApprovals.length;
        final sosInArea = s.sosInMyArea().length;
        final status = s.regionStatus;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Halo, ${u.name}'),
                Text(
                  '${u.role.label} - ${Regions.shortName(u.areaId)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFFBFD0E0),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Notifikasi',
                icon: Badge(
                  label: Text('${s.unreadCount}'),
                  isLabelVisible: s.unreadCount > 0,
                  child: const Icon(Icons.notifications_none),
                ),
                onPressed: () => _open(context, const NotificationsScreen()),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (u.status == AccountStatus.menunggu)
                InfoBanner(
                  icon: Icons.hourglass_top,
                  color: const Color(0xFF8A6100),
                  background: const Color(0xFFFFF4D6),
                  title: 'Akun ${u.role.label} menunggu persetujuan',
                  subtitle:
                      'Sementara hak akses Anda sama seperti warga. Anda akan diberi tahu setelah disetujui.',
                ),
              if (s.offline)
                Card(
                  color: const Color(0xFFFFE9C7),
                  child: ListTile(
                    leading:
                        const Icon(Icons.cloud_off, color: Color(0xFF8A6100)),
                    title: const Text('Mode offline (simulasi)'),
                    subtitle: Text(
                      s.pendingCount > 0
                          ? '${s.pendingCount} laporan menunggu sinkron.'
                          : 'Laporan akan disimpan dan dikirim saat online.',
                    ),
                    trailing: TextButton(
                      onPressed: () {
                        final n = s.setOffline(false);
                        snack(
                            context,
                            n > 0
                                ? '$n laporan berhasil disinkronkan.'
                                : 'Kembali online.');
                      },
                      child: const Text('Online'),
                    ),
                  ),
                ),
              for (final b in recentBroadcasts)
                InfoBanner(
                  icon: Icons.cell_tower,
                  color: severityColor(b.severity),
                  background: const Color(0xFFFAD6CD),
                  title: 'Siaran darurat: ${b.title}',
                  subtitle:
                      '${b.message}\n${b.senderName} - ${timeAgo(b.createdAt)}',
                  onTap: () => _showBroadcast(context, b),
                ),
              _RegionStatusBanner(
                status: status,
                area: Regions.label(
                    Regions.ancestorAtLevel(u.areaId, RegionLevel.kelurahan) ??
                        u.areaId),
              ),
              if (u.role != UserRole.superAdmin) WeatherBanner(areaId: u.areaId),
              for (final h in highlights)
                Card(
                  color: h.tag == 'Evakuasi'
                      ? const Color(0xFFFAD6CD)
                      : const Color(0xFFE3ECF8),
                  child: ListTile(
                    leading: Icon(
                      h.tag == 'Evakuasi' ? Icons.directions_run : Icons.campaign,
                      color: h.tag == 'Evakuasi' ? kRed : kBlue,
                    ),
                    title: Text(h.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${h.tag} - ${h.author}\n${h.body}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    onTap: () => onNavigate(3),
                  ),
                ),
              if (sos != null)
                Card(
                  color: const Color(0xFFFAD6CD),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.sos, color: kRed, size: 32),
                        title: Text('SOS aktif sejak ${clock(sos.createdAt)}'),
                        subtitle: Text(sos.respondedBy == null
                            ? 'Menunggu tanggapan pengurus, petugas, atau relawan.'
                            : 'Ditanggapi ${sos.respondedBy}.'),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _cancelSos(context),
                                child: const Text('Batalkan'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  s.resolveSos();
                                  snack(context, 'Syukurlah. SOS ditutup.');
                                },
                                child: const Text('Saya aman'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              for (final r in alerts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    color: const Color(0xFFFFF3D6),
                    child: ListTile(
                      leading: Icon(
                        Icons.warning_amber_rounded,
                        color: severityColor(r.severity),
                        size: 32,
                      ),
                      title: Text('${r.severity.label}: ${r.category}'),
                      subtitle: Text(
                          '${r.location} - ${Regions.shortName(r.areaId)} - ${timeAgo(r.createdAt)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                          context, ReportDetailScreen(reportId: r.id)),
                    ),
                  ),
                ),
              if (u.role != UserRole.superAdmin) ...[
                const SizedBox(height: 16),
                Center(
                  child: SosButton(
                    active: sos != null,
                    onTriggered: () => _sendSos(context),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Tahan 3 detik untuk mengirim SOS beserta lokasi Anda',
                    style: TextStyle(color: kGray),
                  ),
                ),
                const SizedBox(height: 8),
                _SafetyCard(onOpen: () => _open(context, const FamilySafetyScreen())),
              ],
              if (s.isResponder || s.isAdmin)
                _SupervisorPanel(
                  pendingApprovals: pendingApprovals,
                  sosActive: sosInArea,
                  onOpenSafety: () => _open(context, const FamilySafetyScreen()),
                  onOpenApprovals: () => _open(context, const ApprovalsScreen()),
                  onOpenSos: () => _open(context, const SosMonitorScreen()),
                ),
              SectionTitle(
                  'Ringkasan ${Regions.label(Regions.ancestorAtLevel(u.areaId, RegionLevel.kelurahan) ?? u.areaId)}'),
              Row(
                children: [
                  Expanded(
                      child: _Stat(label: 'Aktif', value: active, color: kRed)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _Stat(
                          label: 'Terverifikasi',
                          value: verified,
                          color: kTeal)),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          _Stat(label: 'Selesai', value: done, color: kBlue)),
                ],
              ),
              const SizedBox(height: 16),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  // Tinggi dihitung dari skala teks agar tidak meluap pada
                  // mode font besar.
                  mainAxisExtent: 72 + 34 * textScaleOf(context),
                ),
                children: [
                  _QuickTile(
                    icon: Icons.add_a_photo,
                    label: 'Lapor Kejadian',
                    color: kTeal,
                    onTap: () => _open(context, const ReportFormScreen()),
                  ),
                  _QuickTile(
                    icon: Icons.map,
                    label: 'Peta Sekitar',
                    color: kBlue,
                    onTap: () => onNavigate(2),
                  ),
                  _QuickTile(
                    icon: Icons.campaign,
                    label: 'Pengumuman',
                    color: kYellow,
                    onTap: () => onNavigate(3),
                  ),
                  _QuickTile(
                    icon: Icons.home_work,
                    label: 'Posko & Logistik',
                    color: kTeal,
                    onTap: () => _open(context, const EvacuationScreen()),
                  ),
                  _QuickTile(
                    icon: Icons.family_restroom,
                    label: 'Keselamatan Keluarga',
                    color: kBlue,
                    onTap: () => _open(context, const FamilySafetyScreen()),
                  ),
                  _QuickTile(
                    icon: Icons.person_search,
                    label: 'Orang Hilang',
                    color: kPurple,
                    onTap: () => _open(context, const MissingScreen()),
                  ),
                  _QuickTile(
                    icon: Icons.contact_phone,
                    label: 'Kontak Darurat',
                    color: kPurple,
                    onTap: () => _open(context, const ContactsScreen()),
                  ),
                  _QuickTile(
                    icon: Icons.menu_book,
                    label: 'Panduan Bencana',
                    color: kRed,
                    onTap: () => _open(context, const GuideScreen()),
                  ),
                  if (s.isPetugas)
                    _QuickTile(
                      icon: Icons.assignment_ind,
                      label: 'Tugas Saya',
                      color: kPurple,
                      badge: s.myTasks.length,
                      onTap: () => _open(context, const TasksScreen()),
                    ),
                  if (s.isResponder)
                    _QuickTile(
                      icon: Icons.volunteer_activism,
                      label: 'Papan Relawan',
                      color: kTeal,
                      badge: s.openHelpCount,
                      onTap: () => _open(context, const HelpBoardScreen()),
                    ),
                  if (s.canBroadcast)
                    _QuickTile(
                      icon: Icons.cell_tower,
                      label: 'Siaran Darurat',
                      color: kRed,
                      onTap: () => _open(context, const BroadcastScreen()),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _RegionStatusBanner extends StatelessWidget {
  final RegionStatus status;
  final String area;
  const _RegionStatusBanner({required this.status, required this.area});

  @override
  Widget build(BuildContext context) {
    final (Color color, Color bg, IconData icon, String text) = switch (status) {
      RegionStatus.aman => (
          kTeal,
          const Color(0xFFDDF3EF),
          Icons.verified_user,
          'Tidak ada laporan bahaya yang aktif di wilayah Anda.'
        ),
      RegionStatus.siaga => (
          const Color(0xFF8A6100),
          const Color(0xFFFFF3D6),
          Icons.warning_amber_rounded,
          'Ada laporan waspada yang terverifikasi di wilayah Anda.'
        ),
      RegionStatus.darurat => (
          kRed,
          const Color(0xFFFAD6CD),
          Icons.emergency,
          'Ada laporan bahaya atau siaran darurat di wilayah Anda. Ikuti arahan petugas.'
        ),
    };
    return InfoBanner(
      icon: icon,
      color: color,
      background: bg,
      title: 'Status $area: ${status.label}',
      subtitle: text,
    );
  }
}

/// Status keselamatan diri sendiri langsung dari beranda.
class _SafetyCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _SafetyCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final family = s.myFamily;
    final self = family.first;
    final others = family.length - 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.family_restroom, color: kBlue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Status keselamatan Anda',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: onOpen,
                  child: Text(others > 0 ? 'Keluarga ($others)' : 'Keluarga'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final st in SafetyStatus.values)
                  ChoiceChip(
                    avatar: Icon(st.icon, size: 18),
                    label: Text(st.label),
                    selected: self.status == st,
                    onSelected: (_) {
                      s.setSafety(self, st);
                      if (st == SafetyStatus.butuhBantuan) {
                        snack(context,
                            'Pengurus dan relawan di wilayah Anda diberi tahu.');
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ringkasan untuk pengurus, petugas, relawan, dan admin.
class _SupervisorPanel extends StatelessWidget {
  final int pendingApprovals;
  final int sosActive;
  final VoidCallback onOpenSafety;
  final VoidCallback onOpenApprovals;
  final VoidCallback onOpenSos;
  const _SupervisorPanel({
    required this.pendingApprovals,
    required this.sosActive,
    required this.onOpenSafety,
    required this.onOpenApprovals,
    required this.onOpenSos,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final t = s.areaSafetyTotals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Pantauan ${Regions.shortName(s.myAuthorityArea)}'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _Stat(label: 'Aman', value: t.safe, color: kTeal)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _Stat(
                            label: 'Butuh bantuan',
                            value: t.needHelp,
                            color: kRed)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _Stat(
                            label: 'Belum diketahui',
                            value: t.unknown + t.notReported,
                            color: kGray)),
                  ],
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.groups),
                  title: const Text('Rincian per rumah tangga'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenSafety,
                ),
                if (s.canSeeSos)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.sos,
                        color: sosActive > 0 ? kRed : kGray),
                    title: Text(sosActive > 0
                        ? '$sosActive SOS aktif di wilayah'
                        : 'Pemantau SOS'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: onOpenSos,
                  ),
                if (s.canApproveAccounts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.how_to_reg),
                    title: const Text('Persetujuan akun'),
                    trailing: Badge(
                      label: Text('$pendingApprovals'),
                      isLabelVisible: pendingApprovals > 0,
                      child: const Icon(Icons.chevron_right),
                    ),
                    onTap: onOpenApprovals,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: color),
            ),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: kGray)),
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badge;
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Badge(
                label: Text('$badge'),
                isLabelVisible: badge > 0,
                child: CircleAvatar(
                  backgroundColor: color,
                  child: Icon(icon, color: Colors.white),
                ),
              ),
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
