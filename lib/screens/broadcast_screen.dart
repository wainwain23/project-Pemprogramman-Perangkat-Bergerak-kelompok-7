import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../geo.dart';
import '../models.dart';
import '../services/location_service.dart';
import '../services/push_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/region_picker.dart';

/// Siaran darurat: pusat atau petugas mengirim peringatan beralarm ke seluruh
/// warga di wilayah (atau radius) bencana.
class BroadcastScreen extends StatelessWidget {
  const BroadcastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Siaran Darurat'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFBFD0E0),
            tabs: [Tab(text: 'Kirim'), Tab(text: 'Riwayat')],
          ),
        ),
        body: ListenableBuilder(
          listenable: AppState.instance,
          builder: (context, _) {
            if (!AppState.instance.canBroadcast) {
              return const EmptyState(
                icon: Icons.lock_outline,
                text:
                    'Hanya Admin Wilayah, Petugas Lapangan, dan Super Admin yang boleh menyiarkan peringatan darurat.',
              );
            }
            return const TabBarView(
              children: [_ComposeTab(), _HistoryTab()],
            );
          },
        ),
      ),
    );
  }
}

class _ComposeTab extends StatefulWidget {
  const _ComposeTab();

  @override
  State<_ComposeTab> createState() => _ComposeTabState();
}

class _ComposeTabState extends State<_ComposeTab> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  Severity _severity = Severity.bahaya;
  String? _areaId; // null = seluruh wilayah kewenangan
  bool _useRadius = false;
  double _radiusM = 2000;
  LocationFix? _center;
  bool _locating = false;
  bool _sending = false;
  String? _error;
  int _pickerGen = 0;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  String get _targetArea => _areaId ?? AppState.instance.myAuthorityArea;

  Future<void> _locate() async {
    setState(() => _locating = true);
    final res = await LocationService.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (res.ok) {
        _center = res.fix;
        AppState.instance.updateMyLocation(res.fix!.lat, res.fix!.lng);
      }
    });
    if (!res.ok) {
      snack(context, res.message);
    }
  }

  Future<void> _send() async {
    final s = AppState.instance;
    if (_useRadius && _center == null) {
      setState(() => _error =
          'Ambil lokasi dulu untuk menentukan titik pusat radius, atau matikan radius.');
      return;
    }
    final lat = _useRadius ? _center!.lat : null;
    final lng = _useRadius ? _center!.lng : null;
    final radius = _useRadius ? _radiusM : null;
    final count = s.broadcastAudienceCount(_targetArea,
        lat: lat, lng: lng, radiusM: radius);
    final ok = await confirmDialog(
      context,
      title: 'Kirim siaran darurat?',
      text:
          'Alarm layar penuh akan muncul di $count akun di ${Regions.shortName(_targetArea)}'
          '${radius == null ? '' : ' (radius ${radius.round()} m)'}. '
          'Gunakan hanya untuk keadaan darurat yang nyata.',
      confirm: 'Kirim sekarang',
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    final res = s.sendBroadcast(
      title: _title.text,
      message: _message.text,
      severity: _severity,
      areaId: _targetArea,
      lat: lat,
      lng: lng,
      radiusM: radius,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!res.success) {
      setState(() => _error = res.error);
      return;
    }
    _title.clear();
    _message.clear();
    setState(() {
      _error = null;
      _areaId = null;
      _useRadius = false;
      _center = null;
      _pickerGen++;
    });
    snack(context,
        'Siaran terkirim ke ${res.broadcast!.recipients} akun. Lihat tab Riwayat.');
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final area = _targetArea;
    final preview = s.broadcastAudienceCount(
      area,
      lat: _useRadius ? _center?.lat : null,
      lng: _useRadius ? _center?.lng : null,
      radiusM: _useRadius && _center != null ? _radiusM : null,
    );
    final fcmReady = PushService.instance.ready;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoBanner(
          icon: fcmReady ? Icons.cloud_done : Icons.cloud_off,
          color: fcmReady ? kTeal : const Color(0xFF8A6100),
          background:
              fcmReady ? const Color(0xFFDDF3EF) : const Color(0xFFFFF4D6),
          title: fcmReady
              ? 'FCM aktif di perangkat ini'
              : 'FCM belum dikonfigurasi',
          subtitle: fcmReady
              ? 'Pengiriman ke perangkat lain dilakukan server lewat topik wilayah (lihat docs/FCM_SETUP.md). Tombol di bawah menyampaikan ke akun di aplikasi ini.'
              : 'Siaran hanya sampai ke akun yang ada di aplikasi ini (simulasi). Hubungkan proyek Firebase agar sampai ke perangkat warga.',
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _title,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Judul peringatan',
            hintText: 'Contoh: Banjir bandang, segera mengungsi',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _message,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Isi pesan dan instruksi',
            hintText: 'Apa yang terjadi, ke mana harus pergi, siapa yang dihubungi',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        const Text('Tingkat', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final v in Severity.values.reversed)
              ChoiceChip(
                label: Text(v.label),
                selected: _severity == v,
                selectedColor: severityColor(v).withAlpha(70),
                onSelected: (_) => setState(() => _severity = v),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.place, color: kRed),
            title: const Text('Wilayah tujuan'),
            subtitle: Text(Regions.fullName(area)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Bawaan: seluruh wilayah kewenangan Anda. Pilih wilayah lain untuk mempersempit.',
                    style: TextStyle(fontSize: 12, color: kGray),
                  ),
                ),
              ),
              RegionPicker(
                key: ValueKey('bc-picker-$_pickerGen'),
                minLevel: RegionLevel.provinsi,
                onChanged: (id) => setState(() {
                  _areaId = id;
                  _error = null;
                }),
              ),
              if (_areaId != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _areaId = null;
                      _pickerGen++;
                    }),
                    child: const Text('Kembali ke wilayah kewenangan'),
                  ),
                ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.radar),
                title: const Text('Batasi dengan radius'),
                subtitle: const Text(
                    'Hanya warga yang lokasi terakhirnya dalam radius dari titik kejadian'),
                value: _useRadius,
                onChanged: (v) => setState(() {
                  _useRadius = v;
                  _error = null;
                }),
              ),
              if (_useRadius)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Radius: ${formatDistance(_radiusM)}'),
                      Slider(
                        min: 500,
                        max: 20000,
                        divisions: 39,
                        value: _radiusM,
                        label: formatDistance(_radiusM),
                        onChanged: (v) => setState(() => _radiusM = v),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _center == null
                                  ? 'Titik pusat belum diambil'
                                  : 'Pusat: ${formatCoord(_center!.lat, _center!.lng)} (akurasi ${_center!.accuracyM.round()} m)',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _locating ? null : _locate,
                            icon: _locating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.my_location, size: 18),
                            label: const Text('Lokasi saya'),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Warga yang lokasinya belum diketahui tetap menerima siaran (lebih baik berlebih daripada terlewat).',
                          style: TextStyle(fontSize: 12, color: kGray),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Perkiraan penerima: $preview akun',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: kRed)),
          ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _sending ? null : _send,
          icon: const Icon(Icons.cell_tower),
          label: const Text('Kirim siaran darurat'),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) => _buildList(),
    );
  }

  Widget _buildList() {
    final list = AppState.instance.sentBroadcasts;
    if (list.isEmpty) {
      return const EmptyState(
          icon: Icons.history, text: 'Belum ada siaran yang Anda kirim.');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final b in list)
          Card(
            child: ExpansionTile(
              leading: Icon(Icons.cell_tower, color: severityColor(b.severity)),
              title: Text(b.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '${dateTimeLabel(b.createdAt)} - ${Regions.shortName(b.areaId)}'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.message),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    StatusChip(
                        label: b.severity.label,
                        color: severityColor(b.severity)),
                    StatusChip(
                        label: 'Diterima ${b.recipients}', color: kBlue),
                    StatusChip(
                        label: 'Dibaca ${b.acknowledged}', color: kTeal),
                    if (b.hasCenter)
                      StatusChip(
                          label: 'Radius ${formatDistance(b.radiusM!)}',
                          color: kPurple),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
