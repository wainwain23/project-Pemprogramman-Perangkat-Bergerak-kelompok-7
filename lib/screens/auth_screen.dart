import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/region_picker.dart';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _hide = true;
  UserRole _role = UserRole.warga;
  String? _areaId;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fill(String email) {
    setState(() {
      _email.text = email;
      _password.text = '123456';
      _error = null;
    });
  }

  Future<void> _forgot() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _ResetDialog(initialEmail: _email.text),
    );
    if (email == null || !mounted) return;
    setState(() {
      _email.text = email;
      _password.clear();
      _error = null;
    });
    snack(context, 'Kata sandi diperbarui. Silakan masuk.');
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final s = AppState.instance;
    String? err;
    if (_register) {
      if (_areaId == null) {
        setState(() => _error = 'Pilih wilayah sampai tingkat RT');
        return;
      }
      err = s.register(AppUser(
        name: _name.text.trim(),
        email: _email.text.trim().toLowerCase(),
        phone: _phone.text.trim(),
        password: _password.text,
        role: _role,
        areaId: _areaId!,
      ));
    } else {
      err = s.login(_email.text, _password.text);
    }
    if (err != null) setState(() => _error = err);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: kRed,
                    child: Icon(Icons.shield, size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Warga Siaga',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Waspada bersama, selamat bersama',
                    style: TextStyle(color: Color(0xFFBFD0E0)),
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<bool>(
                    style: SegmentedButton.styleFrom(
                      backgroundColor: kNavy,
                      foregroundColor: Colors.white,
                      selectedBackgroundColor: kRed,
                      selectedForegroundColor: Colors.white,
                    ),
                    segments: const [
                      ButtonSegment(value: false, label: Text('Masuk')),
                      ButtonSegment(value: true, label: Text('Daftar')),
                    ],
                    selected: {_register},
                    onSelectionChanged: (v) => setState(() {
                      _register = v.first;
                      _error = null;
                      // Pemilih wilayah dibuat ulang (kosong) tiap kali tab
                      // Daftar dibuka, jadi pilihan lama harus ikut dibuang.
                      _areaId = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_register) ...[
                              TextFormField(
                                controller: _name,
                                decoration: const InputDecoration(
                                  labelText: 'Nama lengkap',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Nama wajib diisi'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email wajib diisi';
                                }
                                if (!_emailPattern.hasMatch(v.trim())) {
                                  return 'Format email tidak valid';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            if (_register) ...[
                              TextFormField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Nomor HP',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().length < 8)
                                        ? 'Nomor HP tidak valid'
                                        : null,
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextFormField(
                              controller: _password,
                              obscureText: _hide,
                              decoration: InputDecoration(
                                labelText: 'Kata sandi',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_hide
                                      ? Icons.visibility
                                      : Icons.visibility_off),
                                  onPressed: () =>
                                      setState(() => _hide = !_hide),
                                ),
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'Minimal 6 karakter'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            if (_register) ...[
                              DropdownButtonFormField<UserRole>(
                                value: _role,
                                decoration: const InputDecoration(
                                  labelText: 'Daftar sebagai',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                                items: [
                                  for (final r in UserRole.values)
                                    if (r.selfRegisterable)
                                      DropdownMenuItem(
                                        value: r,
                                        child: Text(r.label),
                                      ),
                                ],
                                onChanged: (v) => setState(
                                    () => _role = v ?? UserRole.warga),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  _role.needsApproval
                                      ? '${_role.description}\nAkun ${_role.label} harus disetujui pengurus wilayah dulu. '
                                          'Sebelum disetujui, hak aksesnya sama seperti warga.'
                                      : _role.description,
                                  style: const TextStyle(
                                      fontSize: 12, color: kGray),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Wilayah tempat tinggal',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 8),
                              RegionPicker(
                                allowAddLocal: true,
                                onChanged: (id) => setState(() {
                                  _areaId = id;
                                  _error = null;
                                }),
                              ),
                            ],
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: kRed),
                                ),
                              ),
                            ElevatedButton(
                              onPressed: _submit,
                              child: Text(_register ? 'Daftar' : 'Masuk'),
                            ),
                            if (!_register) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _forgot,
                                  child: const Text('Lupa kata sandi?'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Akun demo (sandi 123456):',
                                style: TextStyle(fontSize: 12, color: kGray),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  ActionChip(
                                    label: const Text('Warga'),
                                    onPressed: () => _fill('warga@demo.id'),
                                  ),
                                  ActionChip(
                                    label: const Text('Ketua RT'),
                                    onPressed: () => _fill('rt@demo.id'),
                                  ),
                                  ActionChip(
                                    label: const Text('Petugas'),
                                    onPressed: () => _fill('petugas@demo.id'),
                                  ),
                                  ActionChip(
                                    label: const Text('Relawan'),
                                    onPressed: () => _fill('relawan@demo.id'),
                                  ),
                                  ActionChip(
                                    label: const Text('Admin'),
                                    onPressed: () => _fill('admin@demo.id'),
                                  ),
                                  ActionChip(
                                    label: const Text('Super Admin'),
                                    onPressed: () => _fill('super@demo.id'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Versi awal: akun disimpan di memori, belum terhubung server.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFBFD0E0), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog reset kata sandi dua langkah (simulasi): minta kode, lalu masukkan
/// kode dan kata sandi baru. Pada versi lengkap kode dikirim ke email oleh
/// server; di sini kode ditampilkan di layar agar bisa didemokan.
class _ResetDialog extends StatefulWidget {
  final String initialEmail;
  const _ResetDialog({required this.initialEmail});

  @override
  State<_ResetDialog> createState() => _ResetDialogState();
}

class _ResetDialogState extends State<_ResetDialog> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _pass = TextEditingController();
  String? _sentCode;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _send() {
    final code = AppState.instance.requestPasswordReset(_email.text);
    setState(() {
      if (code == null) {
        _error = 'Email tidak terdaftar';
      } else {
        _sentCode = code;
        _error = null;
      }
    });
  }

  void _confirm() {
    final err = AppState.instance
        .confirmPasswordReset(_email.text, _code.text, _pass.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(context, _email.text.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Atur ulang kata sandi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _email,
              enabled: _sentCode == null,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            if (_sentCode != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Kode verifikasi (simulasi email): $_sentCode\n'
                  'Berlaku ${AppState.resetCodeTtl.inMinutes} menit.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kode 6 angka'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Kata sandi baru (min. 6 karakter)',
                ),
              ),
            ],
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _sentCode == null ? _send : _confirm,
          child: Text(_sentCode == null ? 'Kirim kode' : 'Simpan'),
        ),
      ],
    );
  }
}
