import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/seed.dart';
import '../geo.dart';
import '../models.dart';
import '../safety_models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Panduan sebelum, saat, dan sesudah bencana (bisa dibaca offline).
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  Widget _block(String title, List<String> items, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          for (final t in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(t)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panduan Bencana')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Panduan umum. Ikuti arahan petugas BPBD dan pengurus wilayah setempat.',
            style: TextStyle(color: kGray),
          ),
          const SizedBox(height: 12),
          for (final g in kGuides)
            Card(
              child: ExpansionTile(
                shape: const Border(),
                title: Text(g.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(g.subtitle),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block('Sebelum', g.before, kBlue),
                  _block('Saat kejadian', g.during, kRed),
                  _block('Sesudah', g.after, kTeal),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  Future<void> _addPersonal(BuildContext context) async {
    final name = await promptText(context,
        title: 'Tambah kontak darurat', label: 'Nama', confirm: 'Lanjut');
    if (name == null || !context.mounted) return;
    final phone = await promptText(context,
        title: 'Nomor HP $name',
        label: 'Nomor HP',
        keyboardType: TextInputType.phone);
    if (phone == null || !context.mounted) return;
    if (phone.replaceAll(RegExp(r'[^0-9]'), '').length < 3) {
      snack(context, 'Nomor telepon tidak valid.');
      return;
    }
    AppState.instance.addContact(EmergencyContact(name, phone));
  }

  Future<void> _addLocal(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddLocalContactDialog(),
    );
    if (ok == true && context.mounted) snack(context, 'Nomor penting ditambahkan.');
  }

  Widget _callTile(BuildContext context, IconData icon, Color color,
      String title, String subtitle, String phone,
      {Widget? extra}) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: extra ??
            IconButton(
              tooltip: 'Telepon $title',
              icon: const Icon(Icons.call, color: kTeal),
              onPressed: () => callPhone(context, phone),
            ),
        onTap: () => callPhone(context, phone),
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
        final mine = s.myContacts;
        final local = s.localContactsForMe;
        return Scaffold(
          appBar: AppBar(title: const Text('Kontak Darurat')),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: kRed,
            foregroundColor: Colors.white,
            onPressed: () => _addPersonal(context),
            icon: const Icon(Icons.person_add),
            label: const Text('Kontak pribadi'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
            children: [
              const SectionTitle('Nomor darurat nasional'),
              const Text(
                'Ketuk untuk menelepon. Periksa kembali nomor resmi di daerah Anda.',
                style: TextStyle(fontSize: 12, color: kGray),
              ),
              const SizedBox(height: 8),
              for (final c in buildNationalContacts())
                _callTile(context, Icons.phone, kRed, c.name, c.phone, c.phone),
              SectionTitle(
                'Nomor penting setempat',
                trailing: s.canPostAnnouncement
                    ? TextButton.icon(
                        onPressed: () => _addLocal(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah'),
                      )
                    : null,
              ),
              const Text(
                'Rumah sakit, puskesmas, dan BPBD di wilayah Anda, diisi oleh pengurus. Nomor contoh harus diganti nomor resmi.',
                style: TextStyle(fontSize: 12, color: kGray),
              ),
              const SizedBox(height: 8),
              if (local.isEmpty)
                const Text('Belum ada nomor setempat untuk wilayah Anda.'),
              for (final c in local)
                _callTile(
                  context,
                  c.kind.icon,
                  kBlue,
                  c.name,
                  '${c.kind.label} - ${c.phone}'
                      '${c.address.isEmpty ? '' : '\n${c.address}'}',
                  c.phone,
                  extra: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.canManageLocalContact(c))
                        IconButton(
                          tooltip: 'Hapus',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => s.removeLocalContact(c),
                        ),
                      IconButton(
                        tooltip: 'Telepon ${c.name}',
                        icon: const Icon(Icons.call, color: kTeal),
                        onPressed: () => callPhone(context, c.phone),
                      ),
                    ],
                  ),
                ),
              const SectionTitle('Kontak pribadi'),
              const Text(
                'Keluarga atau tetangga yang ingin Anda hubungi saat darurat.',
                style: TextStyle(fontSize: 12, color: kGray),
              ),
              const SizedBox(height: 8),
              if (mine.isEmpty)
                const Text('Belum ada kontak. Tambahkan minimal satu.'),
              for (final c in mine)
                _callTile(
                  context,
                  Icons.person,
                  kPurple,
                  c.name,
                  c.phone,
                  c.phone,
                  extra: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => s.removeContact(c),
                      ),
                      IconButton(
                        tooltip: 'Telepon ${c.name}',
                        icon: const Icon(Icons.call, color: kTeal),
                        onPressed: () => callPhone(context, c.phone),
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

class _AddLocalContactDialog extends StatefulWidget {
  const _AddLocalContactDialog();

  @override
  State<_AddLocalContactDialog> createState() => _AddLocalContactDialogState();
}

class _AddLocalContactDialogState extends State<_AddLocalContactDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  LocalContactKind _kind = LocalContactKind.rumahSakit;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    final err = AppState.instance.addLocalContact(
      name: _name.text,
      phone: _phone.text,
      kind: _kind,
      address: _address.text,
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
      title: const Text('Tambah nomor penting'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<LocalContactKind>(
              value: _kind,
              decoration: const InputDecoration(labelText: 'Jenis'),
              items: [
                for (final k in LocalContactKind.values)
                  DropdownMenuItem(value: k, child: Text(k.label)),
              ],
              onChanged: (v) => setState(() => _kind = v ?? _kind),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor telepon'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _address,
              decoration: const InputDecoration(labelText: 'Alamat (opsional)'),
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

/// Riwayat SOS milik pengguna: aktif, selesai (aman), atau dibatalkan beserta alasan.
class SosHistoryScreen extends StatelessWidget {
  const SosHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        final list = s.sosHistory;
        return Scaffold(
          appBar: AppBar(title: const Text('Riwayat SOS')),
          body: list.isEmpty
              ? const EmptyState(
                  icon: Icons.history, text: 'Belum ada riwayat SOS.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final e = list[i];
                    final color = e.isActive
                        ? kRed
                        : (e.cancelledAt != null ? kGray : kTeal);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color,
                          child: const Icon(Icons.sos, color: Colors.white),
                        ),
                        title: Text('SOS ${dateTimeLabel(e.createdAt)}'),
                        subtitle: Text(
                          '${e.statusLabel}\n'
                          '${e.hasCoordinates ? 'Lokasi: ${formatCoord(e.lat!, e.lng!)}' : 'Tanpa lokasi GPS'}'
                          '${e.viaSms ? ' (via SMS)' : ''}',
                        ),
                        isThreeLine: true,
                        trailing: Text(timeAgo(e.createdAt),
                            style: const TextStyle(fontSize: 11, color: kGray)),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
