import 'package:flutter/material.dart';
import '../app_state.dart';
import '../config.dart';
import '../data/regions.dart';
import '../geo.dart';
import '../models.dart';
import '../services/camera_service.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'report_detail_screen.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _desc = TextEditingController();
  final _place = TextEditingController();
  String _category = kCategories.first.name;
  String? _photoPath;
  bool _submitting = false;

  LocationFix? _fix;
  LocationFailure? _locFailure;
  String? _locMessage;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _desc.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locMessage = null;
      _locFailure = null;
    });
    final res = await LocationService.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (res.ok) {
        _fix = res.fix;
      } else {
        _locFailure = res.failure;
        _locMessage = res.message;
      }
    });
  }

  Future<void> _takePhoto() async {
    final res = await CameraService.capture();
    if (!mounted) return;
    if (res.ok) {
      setState(() => _photoPath = res.path);
    } else if (res.error != null) {
      snack(context, res.error!);
    }
  }

  Future<void> _submit() async {
    // Cegah kirim ganda akibat ketukan berulang.
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final s = AppState.instance;
    final fix = _fix;

    // Deteksi kemungkinan laporan ganda (radius koordinat, atau RT yang sama).
    final dup = s.findPossibleDuplicate(_category, lat: fix?.lat, lng: fix?.lng);
    if (dup != null) {
      String where = 'di RT Anda';
      if (fix != null && dup.hasCoordinates) {
        final d = haversineM(fix.lat, fix.lng, dup.lat!, dup.lng!);
        where = 'sekitar ${formatDistance(d)} dari lokasi Anda';
      }
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mungkin laporan ganda'),
          content: Text(
            'Sudah ada laporan "${dup.category} - ${dup.location}" $where '
            '(${timeAgo(dup.createdAt)}). Jika kejadiannya sama, cukup '
            'konfirmasi laporan itu agar tidak berganda.'
            '${fix != null && dup.hasCoordinates ? '' : '\n\nPembanding: RT yang sama (koordinat tidak lengkap).'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'send'),
              child: const Text('Tetap kirim'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'view'),
              child: const Text('Lihat laporan'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice != 'send') {
        setState(() => _submitting = false);
        if (choice == 'view') {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => ReportDetailScreen(reportId: dup.id)),
          );
        }
        return;
      }
    }

    final err = s.addReport(
      category: _category,
      description: _desc.text.trim(),
      location: _place.text.trim(),
      photoPath: _photoPath,
      lat: fix?.lat,
      lng: fix?.lng,
      accuracyM: fix?.accuracyM,
    );
    if (err != null) {
      setState(() => _submitting = false);
      snack(context, err);
      return;
    }
    // Ambil messenger sebelum pop agar tidak memakai context yang sudah lepas.
    final messenger = ScaffoldMessenger.of(context);
    final msg = s.offline
        ? 'Offline: laporan disimpan, akan dikirim saat ada internet.'
        : 'Laporan terkirim. Menunggu verifikasi Ketua RT.';
    Navigator.pop(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _locationCard(AppState s) {
    final fix = _fix;
    if (_locating) {
      return const Card(
        child: ListTile(
          leading: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2)),
          title: Text('Mengambil lokasi GPS...'),
        ),
      );
    }
    if (fix != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.my_location, color: kTeal),
          title: Text(formatCoord(fix.lat, fix.lng)),
          subtitle: Text(
              'Akurasi sekitar ${fix.accuracyM.round()} m - ${Regions.shortName(s.me.areaId)}'
              '${fix.accuracyM > AppConfig.duplicateRadiusM ? '\nAkurasi rendah; pindah ke tempat terbuka lalu perbarui.' : ''}'),
          isThreeLine: fix.accuracyM > AppConfig.duplicateRadiusM,
          trailing: IconButton(
            tooltip: 'Perbarui lokasi',
            icon: const Icon(Icons.refresh),
            onPressed: _locate,
          ),
        ),
      );
    }
    final failure = _locFailure;
    return Card(
      color: const Color(0xFFFFF4D6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_off, color: Color(0xFF8A6100)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_locMessage ?? 'Lokasi belum tersedia.'}\n'
                    'Laporan tetap bisa dikirim tanpa koordinat, tetapi petugas akan lebih sulit menemukan lokasi.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _locate,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                ),
                if (failure == LocationFailure.deniedForever ||
                    failure == LocationFailure.serviceOff)
                  TextButton.icon(
                    onPressed: () => LocationService.openSettings(failure!),
                    icon: const Icon(Icons.settings),
                    label: const Text('Buka pengaturan'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Lapor Kejadian')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (s.offline)
            const Card(
              color: Color(0xFFFFE9C7),
              child: ListTile(
                leading: Icon(Icons.cloud_off, color: Color(0xFF8A6100)),
                title: Text('Anda sedang offline'),
                subtitle: Text(
                    'Laporan disimpan di perangkat lalu dikirim otomatis saat online.'),
              ),
            ),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Kategori'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final c in kCategories)
                      ChoiceChip(
                        avatar: Icon(c.icon, size: 18),
                        label: Text(c.name),
                        selected: _category == c.name,
                        onSelected: (_) => setState(() => _category = c.name),
                      ),
                  ],
                ),
                const SectionTitle('Foto'),
                if (_photoPath != null) ...[
                  PhotoThumb(path: _photoPath),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.photo_camera),
                        label: Text(
                            _photoPath == null ? 'Ambil foto' : 'Ganti foto'),
                      ),
                    ),
                    if (_photoPath != null) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => setState(() => _photoPath = null),
                        child: const Text('Hapus'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _place,
                  decoration: const InputDecoration(
                    labelText: 'Patokan lokasi',
                    hintText: 'Contoh: depan gang 3, dekat warung',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Isi patokan lokasi'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _desc,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi kejadian',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'Jelaskan minimal 10 karakter'
                      : null,
                ),
                const SizedBox(height: 12),
                _locationCard(s),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.send),
                  label: const Text('Kirim Laporan'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
