import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../models.dart';
import '../safety_models.dart';
import '../theme.dart';
import '../widgets/common.dart';

Color safetyColor(SafetyStatus s) => switch (s) {
      SafetyStatus.aman => kTeal,
      SafetyStatus.butuhBantuan => kRed,
      SafetyStatus.belumDiketahui => kGray,
    };

/// Status keselamatan keluarga (Saya Aman / Butuh Bantuan / Belum Diketahui).
/// Pengurus, petugas, dan relawan juga melihat tab rekap wilayah.
class FamilySafetyScreen extends StatelessWidget {
  const FamilySafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        if (!s.isResponder) {
          return Scaffold(
            appBar: AppBar(title: const Text('Keselamatan Keluarga')),
            floatingActionButton: const _AddMemberButton(),
            body: const _FamilyTab(),
          );
        }
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Keselamatan'),
              bottom: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xFFBFD0E0),
                tabs: [Tab(text: 'Keluarga saya'), Tab(text: 'Wilayah')],
              ),
            ),
            floatingActionButton: const _AddMemberButton(),
            body: const TabBarView(children: [_FamilyTab(), _AreaTab()]),
          ),
        );
      },
    );
  }
}

class _AddMemberButton extends StatelessWidget {
  const _AddMemberButton();

  Future<void> _add(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddMemberDialog(),
    );
    if (ok == true && context.mounted) snack(context, 'Anggota ditambahkan.');
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: kRed,
      foregroundColor: Colors.white,
      onPressed: () => _add(context),
      icon: const Icon(Icons.person_add),
      label: const Text('Tambah anggota'),
    );
  }
}

class _FamilyTab extends StatelessWidget {
  const _FamilyTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        final family = s.myFamily;
        final allSafe = family.every((m) => m.status == SafetyStatus.aman);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            const Text(
              'Perbarui status Anda dan keluarga. "Butuh bantuan" langsung memberi tahu pengurus, petugas, dan relawan di wilayah Anda.',
              style: TextStyle(fontSize: 12, color: kGray),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: allSafe
                  ? null
                  : () {
                      s.setAllSafe();
                      snack(context, 'Semua anggota ditandai aman.');
                    },
              style: FilledButton.styleFrom(
                  backgroundColor: kTeal,
                  minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.check_circle),
              label: const Text('Kami semua aman'),
            ),
            const SizedBox(height: 8),
            for (final m in family)
              Card(
                key: ValueKey(m.id),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: safetyColor(m.status),
                            child: Icon(m.status.icon, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text(
                                  '${m.relation} - diperbarui ${timeAgo(m.updatedAt)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: kGray),
                                ),
                              ],
                            ),
                          ),
                          if (m.phone.isNotEmpty)
                            IconButton(
                              tooltip: 'Telepon ${m.name}',
                              icon: const Icon(Icons.call, color: kTeal),
                              onPressed: () => callPhone(context, m.phone),
                            ),
                          if (m.id != 'self')
                            IconButton(
                              tooltip: 'Hapus',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final ok = await confirmDialog(
                                  context,
                                  title: 'Hapus ${m.name}?',
                                  text:
                                      'Anggota ini dihapus dari daftar keluarga.',
                                  confirm: 'Hapus',
                                );
                                if (ok) s.removeFamilyMember(m);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final st in SafetyStatus.values)
                            ChoiceChip(
                              label: Text(
                                  m.id == 'self' ? st.label : st.memberLabel),
                              selected: m.status == st,
                              selectedColor: safetyColor(st).withAlpha(60),
                              onSelected: (_) => s.setSafety(m, st),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _name = TextEditingController();
  final _relation = TextEditingController();
  final _phone = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    final err = AppState.instance.addFamilyMember(
      name: _name.text,
      relation: _relation.text,
      phone: _phone.text,
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
      title: const Text('Tambah anggota keluarga'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _relation,
              decoration: const InputDecoration(
                  labelText: 'Hubungan', hintText: 'Anak, ibu, tetangga...'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telepon (opsional)'),
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
        FilledButton(onPressed: _submit, child: const Text('Tambah')),
      ],
    );
  }
}

/// Rekap keselamatan seluruh rumah tangga di wilayah pengawas.
class _AreaTab extends StatelessWidget {
  const _AreaTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        final t = s.areaSafetyTotals;
        final houses = s.householdsInMyArea;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Text('Wilayah: ${Regions.fullName(s.myAuthorityArea)}',
                style: const TextStyle(fontSize: 12, color: kGray)),
            const SizedBox(height: 8),
            Row(
              children: [
                _count('Aman', t.safe, kTeal),
                _count('Butuh bantuan', t.needHelp, kRed),
                _count('Belum diketahui', t.unknown, kGray),
              ],
            ),
            if (t.notReported > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${t.notReported} akun warga belum pernah memperbarui status keluarganya.',
                  style: const TextStyle(fontSize: 12, color: kGray),
                ),
              ),
            const SectionTitle('Rumah tangga'),
            if (houses.isEmpty)
              const EmptyState(
                  icon: Icons.groups, text: 'Belum ada data keluarga di wilayah ini.'),
            for (final h in houses)
              Card(
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: h.needHelp > 0
                        ? kRed
                        : (h.unknown > 0 ? kGray : kTeal),
                    child: Icon(
                      h.needHelp > 0
                          ? Icons.sos
                          : (h.unknown > 0 ? Icons.help : Icons.check),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(h.owner.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${Regions.shortName(h.owner.areaId)}\nAman ${h.safe} - Butuh bantuan ${h.needHelp} - Belum diketahui ${h.unknown}'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    for (final m in h.members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(m.status.icon,
                            color: safetyColor(m.status), size: 20),
                        title: Text('${m.name} (${m.relation})'),
                        subtitle: Text(m.status.memberLabel),
                        trailing: IconButton(
                          tooltip: 'Telepon',
                          icon: const Icon(Icons.call, color: kTeal),
                          onPressed: () => callPhone(context,
                              m.phone.isEmpty ? h.owner.phone : m.phone),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _count(String label, int value, Color color) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              children: [
                Text('$value',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: kGray)),
              ],
            ),
          ),
        ),
      );
}
