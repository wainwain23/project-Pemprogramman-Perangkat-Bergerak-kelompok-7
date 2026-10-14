import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/region_picker.dart';
import 'approvals_screen.dart';
import 'broadcast_screen.dart';
import 'region_manager_screen.dart';
import 'settings_screen.dart';
import 'sos_monitor_screen.dart';
import 'stats_screen.dart';

void _push(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));

Color accountStatusColor(AccountStatus s) => switch (s) {
      AccountStatus.aktif => kTeal,
      AccountStatus.menunggu => kYellow,
      AccountStatus.ditolak => kRed,
      AccountStatus.dinonaktifkan => kGray,
    };

/// Kerangka aplikasi untuk Super Admin: ringkasan nasional, akun, wilayah,
/// dan pengaturan.
class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      SuperAdminDashboard(onNavigate: (i) => setState(() => _index = i)),
      const AccountsScreen(),
      const RegionManagerScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Ringkasan',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts),
            label: 'Akun',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: 'Wilayah',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}

class SuperAdminDashboard extends StatelessWidget {
  final void Function(int) onNavigate;
  const SuperAdminDashboard({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        final sum = s.nationalSummary;
        final pending = s.pendingApprovals.length;
        final sosActive = sum['SOS aktif'] ?? 0;
        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Halo, ${s.me.name}'),
                const Text(
                  'Super Admin - seluruh Indonesia',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFFBFD0E0),
                  ),
                ),
              ],
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (sosActive > 0)
                InfoBanner(
                  icon: Icons.sos,
                  color: kRed,
                  background: const Color(0xFFFAD6CD),
                  title: '$sosActive SOS aktif',
                  subtitle: 'Buka pemantau SOS untuk menanggapi.',
                  onTap: () => _push(context, const SosMonitorScreen()),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in sum.entries)
                    SizedBox(
                      width: 108,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 8),
                          child: Column(
                            children: [
                              Text('${e.value}',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: kNavy)),
                              Text(e.key,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12, color: kGray)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SectionTitle('Kelola'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.how_to_reg),
                      title: const Text('Persetujuan akun'),
                      subtitle: const Text('Ketua RT, Petugas, Relawan'),
                      trailing: Badge(
                        label: Text('$pending'),
                        isLabelVisible: pending > 0,
                        child: const Icon(Icons.chevron_right),
                      ),
                      onTap: () => _push(context, const ApprovalsScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.manage_accounts),
                      title: const Text('Manajemen akun'),
                      subtitle:
                          const Text('Buat akun, ubah peran dan wilayah'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onNavigate(1),
                    ),
                    ListTile(
                      leading: const Icon(Icons.account_tree),
                      title: const Text('Wilayah (RW/RT)'),
                      subtitle: const Text('Tambah RW dan RT yang belum ada'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onNavigate(2),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cell_tower),
                      title: const Text('Siaran darurat'),
                      subtitle: const Text('Kirim peringatan ke wilayah bencana'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _push(context, const BroadcastScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.sos),
                      title: const Text('Pemantau SOS'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _push(context, const SosMonitorScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.bar_chart),
                      title: const Text('Statistik dan ekspor'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _push(context, const StatsScreen()),
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

// ------------------------------------------------------------ daftar akun

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _search = TextEditingController();
  UserRole? _role;
  AccountStatus? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        final q = _search.text.trim().toLowerCase();
        final list = s.allAccounts.where((u) {
          if (_role != null && u.role != _role) return false;
          if (_status != null && u.status != _status) return false;
          if (q.isEmpty) return true;
          return u.name.toLowerCase().contains(q) ||
              u.email.contains(q) ||
              Regions.shortName(u.areaId).toLowerCase().contains(q);
        }).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Manajemen Akun')),
          floatingActionButton: s.isSuperAdmin
              ? FloatingActionButton.extended(
                  onPressed: () => _push(context, const AccountFormScreen()),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Buat akun'),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Cari nama, email, atau wilayah',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('Semua peran'),
                    selected: _role == null,
                    onSelected: (_) => setState(() => _role = null),
                  ),
                  for (final r in UserRole.values)
                    ChoiceChip(
                      label: Text(r.label),
                      selected: _role == r,
                      onSelected: (_) =>
                          setState(() => _role = _role == r ? null : r),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final st in AccountStatus.values)
                    FilterChip(
                      label: Text(st.label),
                      selected: _status == st,
                      onSelected: (_) =>
                          setState(() => _status = _status == st ? null : st),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${list.length} akun',
                  style: const TextStyle(fontSize: 12, color: kGray)),
              if (list.isEmpty)
                const EmptyState(
                    icon: Icons.search_off, text: 'Tidak ada akun yang cocok.'),
              for (final u in list)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: accountStatusColor(u.status),
                      child: Text(
                        u.name.isEmpty ? '?' : u.name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(u.name),
                    subtitle: Text(
                        '${u.role.label} - ${Regions.shortName(u.areaId)}\n${u.email}'),
                    isThreeLine: true,
                    trailing: StatusChip(
                        label: u.status.label,
                        color: accountStatusColor(u.status)),
                    onTap: () =>
                        _push(context, AccountDetailScreen(email: u.email)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------- detail akun

class AccountDetailScreen extends StatelessWidget {
  final String email;
  const AccountDetailScreen({super.key, required this.email});

  Future<void> _deactivate(BuildContext context, AppUser u) async {
    final reason = await promptText(
      context,
      title: 'Nonaktifkan ${u.name}',
      label: 'Alasan',
      hint: 'Akan ditampilkan ke pemilik akun saat masuk',
      confirm: 'Nonaktifkan',
      maxLines: 2,
    );
    if (reason == null || !context.mounted) return;
    final err = AppState.instance
        .setAccountStatus(u, AccountStatus.dinonaktifkan, note: reason);
    snack(context, err ?? 'Akun dinonaktifkan.');
  }

  Future<void> _reject(BuildContext context, AppUser u) async {
    final reason = await promptText(
      context,
      title: 'Tolak ${u.name}',
      label: 'Alasan penolakan',
      confirm: 'Tolak',
      maxLines: 2,
    );
    if (reason == null || !context.mounted) return;
    final err = AppState.instance.rejectAccount(u, reason);
    snack(context, err ?? 'Pendaftaran ditolak.');
  }

  Future<void> _resetPassword(BuildContext context, AppUser u) async {
    final pass = await promptText(
      context,
      title: 'Kata sandi baru untuk ${u.name}',
      label: 'Kata sandi baru (min. 6 karakter)',
      confirm: 'Simpan',
    );
    if (pass == null || !context.mounted) return;
    final err = AppState.instance.resetAccountPassword(u, pass);
    snack(context, err ?? 'Kata sandi diperbarui. Sampaikan ke pemilik akun.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        final u = s.userByEmail(email);
        if (u == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Akun')),
            body: const EmptyState(
                icon: Icons.person_off, text: 'Akun tidak ditemukan.'),
          );
        }
        final self = s.loggedIn && s.me.email == u.email;
        final canEdit = s.isSuperAdmin;
        return Scaffold(
          appBar: AppBar(title: Text(u.name)),
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
                          StatusChip(label: u.role.label, color: kBlue),
                          const SizedBox(width: 8),
                          StatusChip(
                              label: u.status.label,
                              color: accountStatusColor(u.status)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _line(Icons.email_outlined, u.email),
                      _line(Icons.phone_outlined, u.phone),
                      _line(Icons.place,
                          'Wilayah akun: ${Regions.fullName(u.areaId)}'),
                      _line(Icons.admin_panel_settings_outlined,
                          'Kewenangan: ${Regions.fullName(s.authorityAreaOf(u))}'),
                      _line(Icons.event, 'Dibuat ${dateLabel(u.createdAt)}'),
                      if (u.statusNote != null)
                        _line(Icons.info_outline, 'Catatan: ${u.statusNote}'),
                      Text(
                        u.role.description,
                        style: const TextStyle(fontSize: 12, color: kGray),
                      ),
                    ],
                  ),
                ),
              ),
              if (!canEdit)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Hanya Super Admin yang dapat mengubah akun.',
                      style: TextStyle(color: kGray)),
                )
              else ...[
                const SizedBox(height: 8),
                if (u.status == AccountStatus.menunggu && s.canApprove(s.me, u))
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _reject(context, u),
                          child: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            s.approve(u);
                            snack(context, '${u.name} disetujui.');
                          },
                          child: const Text('Setujui'),
                        ),
                      ),
                    ],
                  ),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit_location_alt),
                        title: const Text('Ubah peran dan wilayah'),
                        subtitle: const Text('Berlaku langsung, tanpa ubah kode'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            _push(context, AccountFormScreen(editing: u)),
                      ),
                      ListTile(
                        leading: const Icon(Icons.lock_reset),
                        title: const Text('Atur kata sandi'),
                        onTap: () => _resetPassword(context, u),
                      ),
                      if (!self && u.status != AccountStatus.dinonaktifkan)
                        ListTile(
                          leading: const Icon(Icons.block, color: kRed),
                          title: const Text('Nonaktifkan akun',
                              style: TextStyle(color: kRed)),
                          onTap: () => _deactivate(context, u),
                        ),
                      if (!self &&
                          (u.status == AccountStatus.dinonaktifkan ||
                              u.status == AccountStatus.ditolak))
                        ListTile(
                          leading: const Icon(Icons.check_circle_outline,
                              color: kTeal),
                          title: const Text('Aktifkan kembali'),
                          onTap: () {
                            final err = s.setAccountStatus(
                                u, AccountStatus.aktif);
                            snack(context, err ?? 'Akun diaktifkan.');
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: kGray),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

// ------------------------------------------------- formulir buat / ubah

/// Cara memilih wilayah untuk sebuah peran.
enum _AreaMode { root, supervisor, rt }

_AreaMode _modeOf(UserRole r) => switch (r) {
      UserRole.superAdmin => _AreaMode.root,
      UserRole.admin => _AreaMode.supervisor,
      _ => _AreaMode.rt,
    };

class AccountFormScreen extends StatefulWidget {
  final AppUser? editing;
  const AccountFormScreen({super.key, this.editing});

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.editing?.name ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.editing?.email ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.editing?.phone ?? '');
  final _password = TextEditingController();
  late UserRole _role = widget.editing?.role ?? UserRole.warga;
  late String? _areaId = widget.editing?.areaId;
  String? _error;

  bool get _isEdit => widget.editing != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _onRole(UserRole? r) {
    if (r == null || r == _role) return;
    setState(() {
      final before = _modeOf(_role);
      _role = r;
      if (_modeOf(r) != before) {
        // Jenis pilihan wilayah berubah; pilihan lama tidak berlaku lagi.
        _areaId = _modeOf(r) == _AreaMode.root ? Regions.rootId : null;
      }
      _error = null;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final area = _modeOf(_role) == _AreaMode.root ? Regions.rootId : _areaId;
    if (area == null) {
      setState(() => _error = _modeOf(_role) == _AreaMode.rt
          ? 'Pilih wilayah sampai tingkat RT'
          : 'Pilih wilayah pengawasan (sampai kelurahan, kecamatan, atau kota)');
      return;
    }
    final s = AppState.instance;
    final String? err;
    if (_isEdit) {
      err = s.updateAccount(
        widget.editing!,
        name: _name.text,
        phone: _phone.text,
        role: _role,
        areaId: area,
      );
    } else {
      err = s.createAccount(
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        password: _password.text,
        role: _role,
        areaId: area,
      );
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context);
    snack(context, _isEdit ? 'Akun diperbarui.' : 'Akun dibuat.');
  }

  @override
  Widget build(BuildContext context) {
    final mode = _modeOf(_role);
    final originalMode =
        widget.editing == null ? null : _modeOf(widget.editing!.role);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Ubah akun' : 'Buat akun')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama lengkap'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              enabled: !_isEdit,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) {
                if (_isEdit) return null;
                final t = (v ?? '').trim();
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                  return 'Format email tidak valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor HP'),
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(
                    labelText: 'Kata sandi awal (min. 6 karakter)'),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Minimal 6 karakter'
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<UserRole>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Peran'),
              items: [
                for (final r in UserRole.values)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: _onRole,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_role.description,
                  style: const TextStyle(fontSize: 12, color: kGray)),
            ),
            const SizedBox(height: 16),
            Text(
              switch (mode) {
                _AreaMode.root => 'Wilayah: seluruh Indonesia',
                _AreaMode.supervisor => 'Wilayah pengawasan',
                _AreaMode.rt => 'Wilayah (RT)',
              },
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (mode == _AreaMode.supervisor)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Pilih kelurahan, kecamatan, atau kota. Admin hanya melihat dan mengelola data di dalam wilayah ini.',
                  style: TextStyle(fontSize: 12, color: kGray),
                ),
              ),
            const SizedBox(height: 8),
            if (mode != _AreaMode.root)
              RegionPicker(
                key: ValueKey('picker-${mode.name}'),
                initialId: mode == originalMode ? widget.editing!.areaId : null,
                maxLevel: mode == _AreaMode.supervisor
                    ? RegionLevel.kelurahan
                    : RegionLevel.rt,
                minLevel: mode == _AreaMode.supervisor
                    ? RegionLevel.kota
                    : RegionLevel.rt,
                allowAddLocal: mode == _AreaMode.rt,
                onChanged: (id) => setState(() {
                  _areaId = id;
                  _error = null;
                }),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: kRed)),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _save,
              child: Text(_isEdit ? 'Simpan perubahan' : 'Buat akun'),
            ),
          ],
        ),
      ),
    );
  }
}
