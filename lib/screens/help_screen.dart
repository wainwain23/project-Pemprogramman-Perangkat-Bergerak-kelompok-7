import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../geo.dart';
import '../models.dart';
import '../safety_models.dart';
import '../theme.dart';
import '../widgets/common.dart';

Color helpStatusColor(HelpStatus s) => switch (s) {
      HelpStatus.terbuka => kRed,
      HelpStatus.diambil => kPurple,
      HelpStatus.selesai => kTeal,
    };

/// Papan permintaan bantuan untuk relawan, petugas, dan pengurus: evakuasi,
/// logistik, medis, koordinasi. Permintaan otomatis dibuat dari status
/// "Butuh bantuan" keluarga dan stok posko yang menipis.
class HelpBoardScreen extends StatefulWidget {
  const HelpBoardScreen({super.key});

  @override
  State<HelpBoardScreen> createState() => _HelpBoardScreenState();
}

class _HelpBoardScreenState extends State<HelpBoardScreen> {
  HelpStatus? _filter;

  Future<void> _create() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateHelpDialog(),
    );
    if (ok == true && mounted) snack(context, 'Permintaan dibuat. Relawan diberi tahu.');
  }

  Future<void> _complete(HelpRequest h) async {
    final note = await promptText(
      context,
      title: 'Selesaikan permintaan',
      label: 'Catatan hasil (opsional)',
      confirm: 'Selesai',
      required: false,
      maxLines: 2,
    );
    if (note == null || !mounted) return;
    final err = AppState.instance.completeHelp(h, note);
    snack(context, err ?? 'Permintaan selesai.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        var list = s.visibleHelpRequests;
        if (_filter != null) list = list.where((h) => h.status == _filter).toList();
        final ref = s.myReferencePoint;
        return Scaffold(
          appBar: AppBar(title: const Text('Papan Relawan')),
          floatingActionButton: s.isResponder
              ? FloatingActionButton.extended(
                  backgroundColor: kRed,
                  foregroundColor: Colors.white,
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: const Text('Permintaan'),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilterChip(
                    label: const Text('Semua'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  for (final st in HelpStatus.values)
                    FilterChip(
                      label: Text(st.label),
                      selected: _filter == st,
                      onSelected: (_) =>
                          setState(() => _filter = _filter == st ? null : st),
                    ),
                ],
              ),
              if (list.isEmpty)
                const EmptyState(
                    icon: Icons.volunteer_activism,
                    text: 'Belum ada permintaan bantuan.'),
              for (final h in list)
                Card(
                  key: ValueKey(h.id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: helpStatusColor(h.status),
                              child: Icon(h.type.icon, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(h.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                    '${h.type.label} - ${Regions.shortName(h.areaId)} - ${timeAgo(h.createdAt)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: kGray),
                                  ),
                                ],
                              ),
                            ),
                            StatusChip(
                                label: h.status.label,
                                color: helpStatusColor(h.status)),
                          ],
                        ),
                        if (h.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(h.description),
                        ],
                        if (h.lat != null &&
                            h.lng != null &&
                            isValidCoord(h.lat, h.lng))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Lokasi: ${formatCoord(h.lat!, h.lng!)}'
                              '${ref == null ? '' : ' (sekitar ${formatDistance(haversineM(ref.lat, ref.lng, h.lat!, h.lng!))} dari Anda)'}',
                              style: const TextStyle(fontSize: 12, color: kGray),
                            ),
                          ),
                        Text(
                          'Dibuat ${h.createdByName}'
                          '${h.claimedByName == null ? '' : ' - ditangani ${h.claimedByName}'}'
                          '${h.doneNote == null ? '' : '\nHasil: ${h.doneNote}'}',
                          style: const TextStyle(fontSize: 12, color: kGray),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (s.canClaimHelp(h))
                              FilledButton(
                                onPressed: () {
                                  final err = s.claimHelp(h);
                                  snack(context, err ?? 'Permintaan Anda ambil.');
                                },
                                child: const Text('Ambil'),
                              ),
                            if (h.status == HelpStatus.diambil &&
                                h.claimedByEmail == s.me.email)
                              OutlinedButton(
                                onPressed: () {
                                  final err = s.releaseHelp(h);
                                  snack(context, err ?? 'Permintaan dilepas.');
                                },
                                child: const Text('Lepas'),
                              ),
                            if (s.canCompleteHelp(h))
                              OutlinedButton(
                                onPressed: () => _complete(h),
                                child: const Text('Selesai'),
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

class _CreateHelpDialog extends StatefulWidget {
  const _CreateHelpDialog();

  @override
  State<_CreateHelpDialog> createState() => _CreateHelpDialogState();
}

class _CreateHelpDialogState extends State<_CreateHelpDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  HelpType _type = HelpType.evakuasi;
  bool _withLocation = true;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _submit() {
    final s = AppState.instance;
    final err = s.createHelpRequest(
      type: _type,
      title: _title.text,
      description: _desc.text,
      lat: _withLocation && s.me.hasLocation ? s.me.lastLat : null,
      lng: _withLocation && s.me.hasLocation ? s.me.lastLng : null,
    );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final hasLoc = AppState.instance.me.hasLocation;
    return AlertDialog(
      title: const Text('Permintaan bantuan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<HelpType>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Jenis'),
              items: [
                for (final t in HelpType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Judul'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Keterangan'),
            ),
            if (hasLoc)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _withLocation,
                onChanged: (v) => setState(() => _withLocation = v ?? false),
                title: const Text('Sertakan lokasi terakhir saya'),
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
        FilledButton(onPressed: _submit, child: const Text('Kirim')),
      ],
    );
  }
}
