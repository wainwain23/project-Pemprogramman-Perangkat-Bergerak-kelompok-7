import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../geo.dart';
import '../models.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Posko / titik evakuasi: daya tampung, jumlah pengungsi, dan stok logistik
/// darurat. Pengurus, petugas, dan relawan di wilayah posko dapat memperbarui
/// datanya; warga hanya melihat.
class EvacuationScreen extends StatefulWidget {
  const EvacuationScreen({super.key});

  @override
  State<EvacuationScreen> createState() => _EvacuationScreenState();
}

class _EvacuationScreenState extends State<EvacuationScreen> {
  GeoPoint? _from;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final u = AppState.instance.currentUser;
    if (u != null && u.hasLocation) _from = GeoPoint(u.lastLat!, u.lastLng!);
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final res = await LocationService.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (res.ok) {
        _from = GeoPoint(res.fix!.lat, res.fix!.lng);
        AppState.instance.updateMyLocation(res.fix!.lat, res.fix!.lng);
      }
    });
    if (!res.ok) snack(context, res.message);
  }

  Future<void> _add() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AddPoskoDialog(from: _from),
    );
    if (ok == true && mounted) snack(context, 'Posko ditambahkan.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        final list = s.poskoNearMe(from: _from);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Posko & Logistik'),
            actions: [
              IconButton(
                tooltip: 'Urutkan dari lokasi saya',
                onPressed: _locating ? null : _locate,
                icon: _locating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.my_location),
              ),
            ],
          ),
          floatingActionButton: s.canAddPosko
              ? FloatingActionButton.extended(
                  backgroundColor: kRed,
                  foregroundColor: Colors.white,
                  onPressed: _add,
                  icon: const Icon(Icons.add_home_work),
                  label: const Text('Tambah posko'),
                )
              : null,
          body: list.isEmpty
              ? const EmptyState(
                  icon: Icons.home_work_outlined,
                  text:
                      'Belum ada posko di kota Anda.\nKetua RT, petugas, atau admin dapat menambahkannya.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    Text(
                      _from == null
                          ? 'Posko di kota Anda. Tekan ikon lokasi untuk mengurutkan dari yang terdekat.'
                          : 'Diurutkan dari yang terdekat dengan lokasi Anda.',
                      style: const TextStyle(fontSize: 12, color: kGray),
                    ),
                    const SizedBox(height: 8),
                    for (final p in list)
                      _PoskoCard(key: ValueKey(p.id), posko: p, from: _from),
                  ],
                ),
        );
      },
    );
  }
}

class _PoskoCard extends StatelessWidget {
  final EvacuationPoint posko;
  final GeoPoint? from;
  const _PoskoCard({super.key, required this.posko, required this.from});

  Future<void> _setOccupants(BuildContext context) async {
    final p = posko;
    final text = await promptText(
      context,
      title: 'Jumlah pengungsi',
      label: 'Jumlah orang di posko',
      initial: '${p.occupants}',
      keyboardType: TextInputType.number,
    );
    if (text == null || !context.mounted) return;
    final n = int.tryParse(text);
    if (n == null) {
      snack(context, 'Isi dengan angka.');
      return;
    }
    final err = AppState.instance.setOccupants(p, n);
    if (err != null) snack(context, err);
  }

  Future<void> _setCapacity(BuildContext context) async {
    final p = posko;
    final text = await promptText(
      context,
      title: 'Daya tampung',
      label: 'Daya tampung (orang)',
      initial: '${p.capacity}',
      keyboardType: TextInputType.number,
    );
    if (text == null || !context.mounted) return;
    final n = int.tryParse(text);
    if (n == null) {
      snack(context, 'Isi dengan angka.');
      return;
    }
    final err = AppState.instance.setCapacity(p, n);
    if (err != null) snack(context, err);
  }

  Future<void> _setStock(BuildContext context, LogisticItem item) async {
    final text = await promptText(
      context,
      title: 'Stok ${item.name}',
      label: 'Jumlah (${item.unit})',
      initial: '${item.stock}',
      keyboardType: TextInputType.number,
    );
    if (text == null || !context.mounted) return;
    final n = int.tryParse(text);
    if (n == null) {
      snack(context, 'Isi dengan angka.');
      return;
    }
    final err = AppState.instance.setStock(posko, item, n);
    if (err != null) snack(context, err);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final p = posko;
    final color = poskoColor(p.state);
    final canManage = s.canManagePosko(p);
    String? distance;
    if (from != null && p.hasCoordinates) {
      distance = formatDistance(haversineM(from!.lat, from!.lng, p.lat!, p.lng!));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  child: const Icon(Icons.home_work, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (p.address.isNotEmpty)
                        Text(p.address,
                            style: const TextStyle(fontSize: 13)),
                      Text(
                        '${Regions.shortName(p.areaId)}'
                        '${distance == null ? '' : ' - $distance'}',
                        style: const TextStyle(fontSize: 12, color: kGray),
                      ),
                    ],
                  ),
                ),
                StatusChip(label: p.state.label, color: color),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: p.fill,
                minHeight: 10,
                color: color,
                backgroundColor: const Color(0xFFDCE1E6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${p.occupants} dari ${p.capacity} orang - sisa ${p.remaining} - '
              'diperbarui ${timeAgo(p.updatedAt)}',
              style: const TextStyle(fontSize: 12, color: kGray),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final i in p.logistics)
                  Chip(
                    avatar: Icon(logisticIcon(i.name),
                        size: 16, color: i.low ? kRed : kGray),
                    label: Text(
                        '${i.name}: ${i.stock} ${i.unit}${i.low ? ' (menipis)' : ''}',
                        style: TextStyle(
                            fontSize: 12,
                            color: i.low ? kRed : null,
                            fontWeight:
                                i.low ? FontWeight.bold : FontWeight.normal)),
                    visualDensity: VisualDensity.compact,
                  ),
                if (p.logistics.isEmpty)
                  const Text('Stok logistik belum dicatat.',
                      style: TextStyle(fontSize: 12, color: kGray)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (p.phone != null)
                  OutlinedButton.icon(
                    onPressed: () => callPhone(context, p.phone!),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Telepon'),
                  ),
                if (p.hasCoordinates)
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: formatCoord(p.lat!, p.lng!)));
                      snack(context, 'Koordinat posko disalin.');
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Salin koordinat'),
                  ),
              ],
            ),
            if (canManage) ...[
              const Divider(height: 24),
              const Text('Kelola posko',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  const Expanded(child: Text('Jumlah pengungsi')),
                  IconButton(
                    tooltip: 'Kurangi satu',
                    onPressed: () => s.adjustOccupants(p, -1),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  TextButton(
                    onPressed: () => _setOccupants(context),
                    child: Text('${p.occupants}'),
                  ),
                  IconButton(
                    tooltip: 'Tambah satu',
                    onPressed: () => s.adjustOccupants(p, 1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text('Daya tampung: ${p.capacity}')),
                  TextButton(
                    onPressed: () => _setCapacity(context),
                    child: const Text('Ubah'),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Posko dibuka'),
                value: p.open,
                onChanged: (v) {
                  final err = s.setPoskoOpen(p, v);
                  if (err != null) snack(context, err);
                },
              ),
              const Text('Stok logistik',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              for (final i in p.logistics)
                Row(
                  children: [
                    Icon(logisticIcon(i.name),
                        size: 18, color: i.low ? kRed : kGray),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${i.name} (${i.unit})')),
                    IconButton(
                      tooltip: 'Kurangi',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => s.adjustStock(p, i, -1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    TextButton(
                      onPressed: () => _setStock(context, i),
                      child: Text('${i.stock}',
                          style: TextStyle(
                              color: i.low ? kRed : null,
                              fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      tooltip: 'Tambah',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => s.adjustStock(p, i, 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              const Text(
                'Ketuk angka untuk mengisi jumlah langsung. Stok menipis otomatis memberi tahu pengurus dan membuat permintaan relawan.',
                style: TextStyle(fontSize: 12, color: kGray),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddPoskoDialog extends StatefulWidget {
  final GeoPoint? from;
  const _AddPoskoDialog({required this.from});

  @override
  State<_AddPoskoDialog> createState() => _AddPoskoDialogState();
}

class _AddPoskoDialogState extends State<_AddPoskoDialog> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _capacity = TextEditingController();
  final _phone = TextEditingController();
  bool _useLocation = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _capacity.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final cap = int.tryParse(_capacity.text.trim());
    if (cap == null) {
      setState(() => _error = 'Daya tampung harus berupa angka');
      return;
    }
    final from = widget.from;
    final err = AppState.instance.addPosko(
      name: _name.text,
      address: _address.text,
      capacity: cap,
      phone: _phone.text,
      lat: _useLocation ? from?.lat : null,
      lng: _useLocation ? from?.lng : null,
    );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah posko'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama posko'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Alamat'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _capacity,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Daya tampung (orang)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'Telepon posko (opsional)'),
            ),
            if (widget.from != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _useLocation,
                onChanged: (v) => setState(() => _useLocation = v ?? false),
                title: const Text('Pakai lokasi saya sebagai titik posko'),
                subtitle: Text(formatCoord(widget.from!.lat, widget.from!.lng),
                    style: const TextStyle(fontSize: 12)),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Titik koordinat belum ada. Tekan ikon lokasi di layar sebelumnya agar posko memiliki koordinat.',
                  style: TextStyle(fontSize: 12, color: kGray),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: kRed)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal')),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}
