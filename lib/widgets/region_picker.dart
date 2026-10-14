import 'package:flutter/material.dart';
import '../data/regions.dart';
import '../models.dart';
import '../services/region_api.dart';
import '../theme.dart';
import 'common.dart';

/// Pemilih wilayah bertingkat: provinsi, kota/kabupaten, kecamatan,
/// kelurahan/desa, RW, dan RT.
///
/// Provinsi sampai kelurahan dimuat dari API wilayah (kode Kemendagri) lewat
/// [RegionRepository], dengan cadangan data contoh bila server tak terjangkau.
/// RW dan RT tidak ada di data nasional, jadi dikelola lokal; bila
/// [allowAddLocal] true, pengguna dapat menambahkan nomor RW/RT yang belum ada.
///
/// [onChanged] dipanggil dengan id wilayah terdalam yang dipilih bila
/// tingkatnya sudah mencapai [minLevel], atau null bila belum.
class RegionPicker extends StatefulWidget {
  final String? initialId;

  /// Tingkat terdalam yang ditampilkan.
  final RegionLevel maxLevel;

  /// Tingkat minimal agar pilihan dianggap lengkap.
  final RegionLevel minLevel;
  final bool allowAddLocal;
  final ValueChanged<String?> onChanged;

  const RegionPicker({
    super.key,
    this.initialId,
    this.maxLevel = RegionLevel.rt,
    this.minLevel = RegionLevel.rt,
    this.allowAddLocal = false,
    required this.onChanged,
  });

  @override
  State<RegionPicker> createState() => _RegionPickerState();
}

class _RegionPickerState extends State<RegionPicker> {
  final Map<RegionLevel, String?> _sel = {};
  final Map<RegionLevel, RegionLoad> _loads = {};
  final Set<RegionLevel> _loading = {};
  final Map<RegionLevel, int> _tokens = {};

  List<RegionLevel> get _levels =>
      RegionLevel.values.sublist(0, widget.maxLevel.index + 1);

  @override
  void initState() {
    super.initState();
    final init = widget.initialId;
    if (init != null) {
      for (final r in Regions.chain(init)) {
        if (r.level.index <= widget.maxLevel.index) _sel[r.level] = r.id;
      }
    }
    for (var i = 0; i < _levels.length; i++) {
      if (i == 0 || _sel[_levels[i - 1]] != null) _loadLevel(i);
    }
  }

  Future<void> _loadLevel(int i) async {
    final level = _levels[i];
    final parent = i == 0 ? null : _sel[_levels[i - 1]];
    final token = (_tokens[level] ?? 0) + 1;
    _tokens[level] = token;
    if (i > 0 && parent == null) {
      setState(() {
        _loads.remove(level);
        _loading.remove(level);
      });
      return;
    }
    setState(() => _loading.add(level));
    final load = await RegionRepository.instance.children(parent, level);
    // Abaikan hasil usang (pilihan induk sudah berubah) atau widget terlepas.
    if (!mounted || _tokens[level] != token) return;
    setState(() {
      _loads[level] = load;
      _loading.remove(level);
    });
  }

  void _emit() {
    String? deepest;
    RegionLevel? deepestLevel;
    for (final l in _levels) {
      final s = _sel[l];
      if (s != null) {
        deepest = s;
        deepestLevel = l;
      }
    }
    final complete =
        deepestLevel != null && deepestLevel.index >= widget.minLevel.index;
    widget.onChanged(complete ? deepest : null);
  }

  void _select(int i, String? value) {
    final levels = _levels;
    setState(() {
      _sel[levels[i]] = value;
      for (var j = i + 1; j < levels.length; j++) {
        final l = levels[j];
        _sel[l] = null;
        _loads.remove(l);
        _loading.remove(l);
        _tokens[l] = (_tokens[l] ?? 0) + 1; // batalkan pemuatan yang berjalan
      }
    });
    if (value != null && i + 1 < levels.length) _loadLevel(i + 1);
    _emit();
  }

  Future<void> _addLocal(int i) async {
    final level = _levels[i];
    final parent = _sel[_levels[i - 1]];
    if (parent == null) return;
    final kind = level == RegionLevel.rw ? 'RW' : 'RT';
    final text = await promptText(
      context,
      title: 'Tambah $kind',
      label: 'Nomor $kind',
      hint: 'Contoh: 5',
      confirm: 'Tambah',
      keyboardType: TextInputType.number,
    );
    if (text == null || !mounted) return;
    final region = Regions.addLocalUnit(parent, text);
    if (region == null) {
      snack(context, 'Nomor $kind tidak valid. Isi angka 1 sampai 999.');
      return;
    }
    // Daftar lokal bertambah; pakai Regions.children lagi lewat muat ulang.
    _loads.remove(level);
    _select(i, region.id);
  }

  List<DropdownMenuItem<String>> _items(int i) {
    final level = _levels[i];
    final parent = i == 0 ? null : _sel[_levels[i - 1]];
    final base = _loads[level]?.items ?? Regions.children(parent, level);
    final seen = <String>{};
    final regions = <Region>[];
    for (final r in base) {
      if (seen.add(r.id)) regions.add(r);
    }
    // Pilihan saat ini selalu ada di daftar agar dropdown tidak error.
    final sel = _sel[level];
    if (sel != null && !seen.contains(sel)) {
      final r = Regions.byId(sel);
      if (r != null) regions.add(r);
    }
    return [
      for (final r in regions)
        DropdownMenuItem<String>(
          value: r.id,
          child: Text(r.name, overflow: TextOverflow.ellipsis),
        ),
    ];
  }

  String? get _notice {
    for (final l in _levels) {
      final e = _loads[l]?.error;
      if (e != null) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final notice = _notice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (notice != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4D6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_off, size: 18, color: Color(0xFF8A6100)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(notice,
                      style: const TextStyle(
                          fontSize: 12.5, color: Color(0xFF6B4A00))),
                ),
              ],
            ),
          ),
        for (var i = 0; i < _levels.length; i++) _field(i),
      ],
    );
  }

  Widget _field(int i) {
    final level = _levels[i];
    final parent = i == 0 ? null : _sel[_levels[i - 1]];
    final enabled = i == 0 || parent != null;
    final items = enabled ? _items(i) : <DropdownMenuItem<String>>[];
    final loading = _loading.contains(level);
    final isLocalLevel = level == RegionLevel.rw || level == RegionLevel.rt;
    final canAdd = widget.allowAddLocal && isLocalLevel && enabled;
    final String? helper;
    if (loading) {
      helper = 'Memuat…';
    } else if (enabled && items.isEmpty) {
      helper = isLocalLevel
          ? (canAdd ? 'Belum ada ${level.label}. Tambahkan di bawah.' : 'Belum ada data ${level.label}.')
          : 'Tidak ada data.';
    } else {
      helper = null;
    }
    final selected = _sel[level];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(
                '${level.name}|${parent ?? ''}|${selected ?? ''}|${items.length}'),
            value: selected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: level.label,
              helperText: helper,
            ),
            items: items,
            onChanged: enabled ? (v) => _select(i, v) : null,
          ),
          if (canAdd)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addLocal(i),
                icon: const Icon(Icons.add, size: 18, color: kBlue),
                label: Text(
                    'Tambah ${level == RegionLevel.rw ? 'RW' : 'RT'} baru'),
              ),
            ),
        ],
      ),
    );
  }
}
