import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../geo.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Pemantau SOS untuk pengawas wilayah (Ketua RT, Admin, Petugas, Relawan,
/// Super Admin): melihat SOS warga di wilayahnya dan menanggapinya.
class SosMonitorScreen extends StatefulWidget {
  const SosMonitorScreen({super.key});

  @override
  State<SosMonitorScreen> createState() => _SosMonitorScreenState();
}

class _SosMonitorScreenState extends State<SosMonitorScreen> {
  bool _activeOnly = true;

  Future<void> _respond(SosEvent e) async {
    final err = AppState.instance.respondSos(e);
    if (!mounted) return;
    snack(context, err ?? 'Anda menanggapi SOS ${e.ownerName}. Hubungi atau menuju lokasinya.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        final list = s.sosInMyArea(activeOnly: _activeOnly);
        final ref = s.myReferencePoint;
        return Scaffold(
          appBar: AppBar(title: const Text('Pemantau SOS')),
          body: !s.canSeeSos
              ? const EmptyState(
                  icon: Icons.lock_outline,
                  text: 'Menu ini untuk pengurus, petugas, dan relawan.')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hanya SOS yang masih aktif'),
                      subtitle: Text(
                          'Wilayah: ${Regions.shortName(s.myAuthorityArea)}'),
                      value: _activeOnly,
                      onChanged: (v) => setState(() => _activeOnly = v),
                    ),
                    if (list.isEmpty)
                      EmptyState(
                        icon: Icons.verified_user,
                        text: _activeOnly
                            ? 'Tidak ada SOS aktif di wilayah Anda.'
                            : 'Belum ada SOS di wilayah Anda.',
                      ),
                    for (final e in list) _card(context, s, e, ref),
                  ],
                ),
        );
      },
    );
  }

  Widget _card(BuildContext context, AppState s, SosEvent e, GeoPoint? ref) {
    final owner = s.userByEmail(e.ownerEmail);
    String? distance;
    if (e.hasCoordinates && ref != null) {
      distance = formatDistance(haversineM(ref.lat, ref.lng, e.lat!, e.lng!));
    }
    final canRespond = e.isActive && e.respondedBy == null;
    return Card(
      color: e.isActive ? const Color(0xFFFFF0EC) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sos, color: e.isActive ? kRed : kGray, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.ownerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                          '${Regions.shortName(e.areaId)} - ${dateTimeLabel(e.createdAt)}',
                          style: const TextStyle(fontSize: 12, color: kGray)),
                    ],
                  ),
                ),
                StatusChip(
                    label: e.isActive ? 'Aktif' : 'Selesai',
                    color: e.isActive ? kRed : kGray),
              ],
            ),
            const SizedBox(height: 8),
            Text(e.statusLabel),
            if (e.viaSms)
              const Text('Dikirim lewat SMS (pengirim sedang offline).',
                  style: TextStyle(fontSize: 12, color: kGray)),
            if (e.hasCoordinates)
              Row(
                children: [
                  const Icon(Icons.my_location, size: 16, color: kBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${formatCoord(e.lat!, e.lng!)}${distance == null ? '' : ' (sekitar $distance dari Anda)'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Salin koordinat',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: formatCoord(e.lat!, e.lng!)));
                      snack(context, 'Koordinat disalin.');
                    },
                  ),
                ],
              )
            else
              const Text('Lokasi GPS tidak tersedia.',
                  style: TextStyle(fontSize: 12, color: kGray)),
            if (e.isActive) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (owner != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => callPhone(context, owner.phone),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Hubungi'),
                      ),
                    ),
                  if (owner != null && canRespond) const SizedBox(width: 8),
                  if (canRespond)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _respond(e),
                        icon: const Icon(Icons.directions_run, size: 18),
                        label: const Text('Tanggapi'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
