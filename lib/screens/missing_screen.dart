import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../models.dart';
import '../safety_models.dart';
import '../services/camera_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Papan informasi orang hilang (warga yang terpisah saat evakuasi) di kota
/// pengguna. Foto hanya dari kamera dan bersifat opsional.
class MissingScreen extends StatefulWidget {
  const MissingScreen({super.key});

  @override
  State<MissingScreen> createState() => _MissingScreenState();
}

class _MissingScreenState extends State<MissingScreen> {
  bool _onlySearching = false;

  Future<void> _markFound(MissingPerson p) async {
    final note = await promptText(
      context,
      title: 'Tandai ${p.name} ditemukan',
      label: 'Catatan (opsional)',
      hint: 'Ditemukan di posko mana, kondisi, dst.',
      confirm: 'Tandai ditemukan',
      required: false,
      maxLines: 2,
    );
    if (note == null || !mounted) return;
    final err = AppState.instance.markFound(p, note);
    snack(context, err ?? '${p.name} ditandai ditemukan. Syukurlah.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        var list = s.missingForMe;
        if (_onlySearching) {
          list = list.where((p) => p.status == MissingStatus.dicari).toList();
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Orang Hilang')),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: kRed,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const MissingFormScreen()),
            ),
            icon: const Icon(Icons.person_search),
            label: const Text('Laporkan'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              const Text(
                'Hanya untuk warga yang terpisah saat bencana. Bagikan informasi seperlunya dan hubungi pengurus bila menemukan seseorang.',
                style: TextStyle(fontSize: 12, color: kGray),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hanya yang masih dicari'),
                value: _onlySearching,
                onChanged: (v) => setState(() => _onlySearching = v),
              ),
              if (list.isEmpty)
                const EmptyState(
                    icon: Icons.person_search,
                    text: 'Tidak ada entri orang hilang.'),
              for (final p in list)
                Card(
                  key: ValueKey(p.id),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.photoPath != null) ...[
                          PhotoThumb(path: p.photoPath, height: 160),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${p.name}${p.age == null ? '' : ' (${p.age} th)'}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                            ),
                            StatusChip(
                              label: p.status.label,
                              color: p.status == MissingStatus.dicari
                                  ? kRed
                                  : kTeal,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(p.description),
                        const SizedBox(height: 6),
                        Text('Terakhir terlihat: ${p.lastSeen}',
                            style: const TextStyle(fontSize: 13)),
                        Text(
                          '${Regions.shortName(p.areaId)} - dilaporkan ${timeAgo(p.createdAt)} oleh ${p.reporterName}',
                          style: const TextStyle(fontSize: 12, color: kGray),
                        ),
                        if (p.foundNote != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Catatan: ${p.foundNote}',
                                style: const TextStyle(fontSize: 13)),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  callPhone(context, p.contactPhone),
                              icon: const Icon(Icons.call, size: 18),
                              label: Text('Hubungi ${p.contactName}'),
                            ),
                            if (p.status == MissingStatus.dicari &&
                                s.canManageMissing(p))
                              FilledButton.icon(
                                onPressed: () => _markFound(p),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Sudah ditemukan'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class MissingFormScreen extends StatefulWidget {
  const MissingFormScreen({super.key});

  @override
  State<MissingFormScreen> createState() => _MissingFormScreenState();
}

class _MissingFormScreenState extends State<MissingFormScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _desc = TextEditingController();
  final _lastSeen = TextEditingController();
  final _contactName = TextEditingController();
  final _contactPhone = TextEditingController();
  String? _photo;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = AppState.instance.currentUser;
    if (u != null) {
      _contactName.text = u.name;
      _contactPhone.text = u.phone;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _desc.dispose();
    _lastSeen.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final res = await CameraService.capture();
    if (!mounted) return;
    if (res.ok) {
      setState(() => _photo = res.path);
    } else if (res.error != null) {
      snack(context, res.error!);
    }
  }

  void _submit() {
    final ageText = _age.text.trim();
    int? age;
    if (ageText.isNotEmpty) {
      age = int.tryParse(ageText);
      if (age == null) {
        setState(() => _error = 'Usia harus berupa angka');
        return;
      }
    }
    final err = AppState.instance.addMissing(
      name: _name.text,
      description: _desc.text,
      lastSeen: _lastSeen.text,
      contactName: _contactName.text,
      contactPhone: _contactPhone.text,
      age: age,
      photoPath: _photo,
    );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context);
    snack(context, 'Informasi orang hilang dipublikasikan.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporkan Orang Hilang')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nama'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _age,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Usia (opsional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Ciri-ciri',
              hintText: 'Pakaian, tinggi badan, ciri khusus, kondisi kesehatan',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lastSeen,
            decoration: const InputDecoration(
                labelText: 'Terakhir terlihat di mana dan kapan'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactName,
            decoration: const InputDecoration(labelText: 'Nama kontak'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactPhone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Nomor kontak'),
          ),
          const SizedBox(height: 12),
          if (_photo != null) ...[
            PhotoThumb(path: _photo, height: 160),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.photo_camera),
            label: Text(_photo == null ? 'Ambil foto (opsional)' : 'Ganti foto'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: kRed)),
            ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _submit, child: const Text('Publikasikan')),
        ],
      ),
    );
  }
}
