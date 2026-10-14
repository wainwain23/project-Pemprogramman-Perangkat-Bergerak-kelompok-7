import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/call_service.dart';
import '../theme.dart';

/// Faktor pembesaran teks saat ini (minimal 1.0). Dipakai agar tinggi elemen
/// yang ukurannya tetap ikut membesar pada mode font besar.
double textScaleOf(BuildContext context) =>
    max(1.0, MediaQuery.textScalerOf(context).scale(14) / 14);

Color severityColor(Severity s) => switch (s) {
      Severity.bahaya => kRed,
      Severity.waspada => kYellow,
      Severity.info => kBlue,
    };

Color statusColor(ReportStatus s) => switch (s) {
      ReportStatus.menunggu => kGray,
      ReportStatus.terverifikasi => kTeal,
      ReportStatus.diproses => kPurple,
      ReportStatus.ditolak => kRed,
      ReportStatus.selesai => kBlue,
    };

Color poskoColor(PoskoState s) => switch (s) {
      PoskoState.tersedia => kTeal,
      PoskoState.hampirPenuh => kYellow,
      PoskoState.penuh => kRed,
      PoskoState.tutup => kGray,
    };

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(36),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == kYellow ? const Color(0xFF8A6100) : color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: kGray),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kGray)),
          ],
        ),
      ),
    );
  }
}

void snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Menelepon nomor (membuka aplikasi telepon). Bila perangkat tidak bisa
/// menelepon, nomor ditampilkan agar bisa dihubungi manual.
Future<void> callPhone(BuildContext context, String phone) async {
  final ok = await CallService.call(phone);
  if (!ok && context.mounted) {
    snack(context, 'Tidak dapat memanggil otomatis. Hubungi manual: $phone');
  }
}

/// Dialog konfirmasi ya/tidak.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String text,
  String confirm = 'Ya',
  String cancel = 'Batal',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false), child: Text(cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(confirm)),
      ],
    ),
  );
  return r ?? false;
}

/// Dialog satu isian teks. Mengembalikan teks (sudah dipangkas) atau null
/// bila dibatalkan. Dengan [required] true, isian kosong ditolak di dialog.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  String? hint,
  String confirm = 'Simpan',
  String initial = '',
  int maxLines = 1,
  bool required = true,
  TextInputType? keyboardType,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      label: label,
      hint: hint,
      confirm: confirm,
      initial: initial,
      maxLines: maxLines,
      required: required,
      keyboardType: keyboardType,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  final String title;
  final String label;
  final String? hint;
  final String confirm;
  final String initial;
  final int maxLines;
  final bool required;
  final TextInputType? keyboardType;
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.confirm,
    required this.initial,
    required this.maxLines,
    required this.required,
    required this.keyboardType,
  });

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (widget.required && v.isEmpty) {
      setState(() => _error = '${widget.label} wajib diisi');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        FilledButton(onPressed: _submit, child: Text(widget.confirm)),
      ],
    );
  }
}

/// Foto laporan dari berkas kamera, dengan cadangan bila berkas hilang.
class PhotoThumb extends StatelessWidget {
  final String? path;
  final double height;
  const PhotoThumb({super.key, required this.path, this.height = 180});

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(p),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          width: double.infinity,
          color: const Color(0xFFDCE1E6),
          alignment: Alignment.center,
          child: const Text('Foto tidak dapat ditampilkan',
              style: TextStyle(color: kGray)),
        ),
      ),
    );
  }
}

/// Kartu kecil dengan ikon, judul, dan keterangan (dipakai banyak layar).
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const InfoBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: background,
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
        onTap: onTap,
      ),
    );
  }
}
