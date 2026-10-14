import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/region_picker.dart';
import 'approvals_screen.dart';
import 'broadcast_screen.dart';
import 'info_screens.dart';
import 'region_manager_screen.dart';
import 'sos_monitor_screen.dart';
import 'stats_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _changeArea(BuildContext context) {
    String? picked;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Ganti wilayah'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (AppState.instance.me.role.needsApproval)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Peran pengurus yang pindah wilayah harus disetujui ulang oleh pengurus wilayah baru.',
                      style: TextStyle(fontSize: 12, color: kGray),
                    ),
                  ),
                RegionPicker(
                  initialId: AppState.instance.me.areaId,
                  onChanged: (id) => setLocal(() => picked = id),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: picked == null
                  ? null
                  : () {
                      final err = AppState.instance.changeArea(picked!);
                      Navigator.pop(ctx);
                      if (err != null) snack(context, err);
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        final u = s.me;
        final pending = s.pendingApprovals.length;
        return Scaffold(
          appBar: AppBar(title: const Text('Akun dan Pengaturan')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 26,
                            backgroundColor: kNavy,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(u.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17)),
                                Text(u.email,
                                    style: const TextStyle(
                                        fontSize: 12, color: kGray)),
                              ],
                            ),
                          ),
                          StatusChip(
                            label: u.approved
                                ? u.role.label
                                : '${u.role.label} (${u.status.label.toLowerCase()})',
                            color: u.approved ? kTeal : kYellow,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.place, size: 18, color: kRed),
                          const SizedBox(width: 6),
                          Expanded(child: Text(Regions.fullName(u.areaId))),
                        ],
                      ),
                      if (u.role != UserRole.admin && u.role != UserRole.superAdmin)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _changeArea(context),
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('Ganti wilayah'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    if (s.canApproveAccounts)
                      ListTile(
                        leading: const Icon(Icons.how_to_reg),
                        title: const Text('Persetujuan akun'),
                        subtitle: const Text('Setujui atau tolak pendaftar di wilayah Anda'),
                        trailing: Badge(
                          label: Text('$pending'),
                          isLabelVisible: pending > 0,
                          child: const Icon(Icons.chevron_right),
                        ),
                        onTap: () => _push(context, const ApprovalsScreen()),
                      ),
                    if (s.canManageRegions)
                      ListTile(
                        leading: const Icon(Icons.account_tree),
                        title: const Text('Kelola RW/RT'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _push(context, const RegionManagerScreen()),
                      ),
                    if (s.canBroadcast)
                      ListTile(
                        leading: const Icon(Icons.cell_tower),
                        title: const Text('Siaran darurat'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _push(context, const BroadcastScreen()),
                      ),
                    if (s.canSeeSos)
                      ListTile(
                        leading: const Icon(Icons.sos),
                        title: const Text('Pemantau SOS'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _push(context, const SosMonitorScreen()),
                      ),
                    ListTile(
                      leading: const Icon(Icons.bar_chart),
                      title: const Text('Statistik wilayah'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _push(context, const StatsScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Riwayat SOS'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _push(context, const SosHistoryScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.contact_phone),
                      title: const Text('Kontak darurat'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _push(context, const ContactsScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.menu_book),
                      title: const Text('Panduan bencana'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _push(context, const GuideScreen()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.format_size),
                      title: const Text('Mode font besar'),
                      subtitle: const Text('Memudahkan lansia membaca'),
                      value: s.largeFont,
                      onChanged: s.setLargeFont,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_active_outlined),
                      title: const Text('Peringatan sekitar'),
                      subtitle: const Text('Terima notifikasi kejadian di wilayah Anda'),
                      value: s.alertsEnabled,
                      onChanged: s.setAlerts,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.radar),
                      title: Text('Radius peringatan: ${s.alertRadiusM.round()} m'),
                      subtitle: Slider(
                        min: 200,
                        max: 2000,
                        divisions: 18,
                        value: s.alertRadiusM,
                        label: '${s.alertRadiusM.round()} m',
                        onChanged: s.setRadius,
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.cloud_off),
                      title: const Text('Simulasi mode offline'),
                      subtitle: Text(
                        s.pendingCount > 0
                            ? '${s.pendingCount} laporan menunggu sinkron'
                            : 'Untuk demo: buat laporan tanpa internet',
                      ),
                      value: s.offline,
                      onChanged: (v) {
                        final n = s.setOffline(v);
                        if (!v && n > 0) {
                          snack(context, '$n laporan berhasil disinkronkan.');
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Tentang aplikasi'),
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: 'Warga Siaga',
                        applicationVersion: '0.4.0',
                        children: const [
                          Text(
                            'Aplikasi peringatan dini, tanggap darurat, dan pelaporan warga berbasis lokasi untuk seluruh wilayah.',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: kRed),
                      title: const Text('Keluar', style: TextStyle(color: kRed)),
                      onTap: s.logout,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
