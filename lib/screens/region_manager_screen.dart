import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/region_picker.dart';

/// Pengelolaan RW dan RT. Data wilayah resmi (Kemendagri) berhenti di
/// kelurahan/desa, jadi RW dan RT dibuat dan dikelola di aplikasi oleh Admin
/// Wilayah atau Super Admin.
class RegionManagerScreen extends StatefulWidget {
  const RegionManagerScreen({super.key});

  @override
  State<RegionManagerScreen> createState() => _RegionManagerScreenState();
}

class _RegionManagerScreenState extends State<RegionManagerScreen> {
  String? _kel;
  String? _initial;

  @override
  void initState() {
    super.initState();
    final s = AppState.instance;
    if (s.loggedIn && !s.isSuperAdmin) {
      final area = s.myAuthorityArea;
      if (Regions.levelOf(area) == RegionLevel.kelurahan) {
        _initial = area;
        _kel = area;
      }
    }
  }

  Future<void> _add(String parentId, String kind) async {
    final text = await promptText(
      context,
      title: 'Tambah $kind',
      label: 'Nomor $kind',
      hint: 'Contoh: 7',
      confirm: 'Tambah',
      keyboardType: TextInputType.number,
    );
    if (text == null || !mounted) return;
    final r = AppState.instance.addLocalRegion(parentId, text);
    if (r == null) {
      snack(context,
          'Gagal. Isi angka 1-999 dan pastikan wilayah ini ada di kewenangan Anda.');
    } else {
      snack(context, '${r.name} tersedia.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        final kel = _kel;
        final rws = kel == null
            ? <Region>[]
            : Regions.children(kel, RegionLevel.rw);
        return Scaffold(
          appBar: AppBar(title: const Text('Wilayah (RW/RT)')),
          body: !s.canManageRegions
              ? const EmptyState(
                  icon: Icons.lock_outline,
                  text: 'Hanya Admin Wilayah dan Super Admin yang dapat mengelola RW/RT.')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const InfoBanner(
                      icon: Icons.info_outline,
                      color: kBlue,
                      background: Color(0xFFE3ECF8),
                      title: 'RW dan RT dikelola di aplikasi',
                      subtitle:
                          'Data wilayah nasional hanya sampai kelurahan/desa. Tambahkan RW dan RT yang belum ada di sini.',
                    ),
                    const SizedBox(height: 8),
                    RegionPicker(
                      initialId: _initial,
                      maxLevel: RegionLevel.kelurahan,
                      minLevel: RegionLevel.kelurahan,
                      onChanged: (id) => setState(() => _kel = id),
                    ),
                    if (kel == null)
                      const EmptyState(
                          icon: Icons.account_tree,
                          text: 'Pilih kelurahan/desa untuk melihat RW dan RT.')
                    else ...[
                      SectionTitle(
                        'RW di ${Regions.label(kel)}',
                        trailing: TextButton.icon(
                          onPressed: () => _add(kel, 'RW'),
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah RW'),
                        ),
                      ),
                      if (rws.isEmpty)
                        const Text('Belum ada RW.',
                            style: TextStyle(color: kGray)),
                      for (final rw in rws)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(rw.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _add(rw.id, 'RT'),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('Tambah RT'),
                                    ),
                                  ],
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    for (final rt in Regions.children(
                                        rw.id, RegionLevel.rt))
                                      Chip(label: Text(rt.name)),
                                    if (Regions.children(rw.id, RegionLevel.rt)
                                        .isEmpty)
                                      const Text('Belum ada RT.',
                                          style: TextStyle(color: kGray)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
