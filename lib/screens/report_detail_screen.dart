import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../geo.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;
  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _verify(Report r) async {
    var level = r.severity;
    final chosen = await showDialog<Severity>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Verifikasi laporan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tentukan tingkat bahaya:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final sv in Severity.values)
                    ChoiceChip(
                      label: Text(sv.label),
                      selected: level == sv,
                      onSelected: (_) => setLocal(() => level = sv),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Warga di kelurahan ini akan diberi tahu lewat notifikasi aplikasi.',
                style: TextStyle(fontSize: 12, color: kGray),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, level),
                child: const Text('Verifikasi')),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    AppState.instance.setStatus(r, ReportStatus.terverifikasi, severity: chosen);
    snack(context, 'Laporan terverifikasi. Warga sekitar diberi tahu.');
  }

  Future<void> _reject(Report r) async {
    final reason = await promptText(
      context,
      title: 'Tolak laporan',
      label: 'Alasan penolakan',
      confirm: 'Tolak',
      maxLines: 2,
    );
    if (reason == null || !mounted) return;
    AppState.instance.setStatus(r, ReportStatus.ditolak, reason: reason);
    snack(context, 'Laporan ditolak.');
  }

  Future<void> _fieldReport(Report r) async {
    final text = await promptText(
      context,
      title: 'Laporan kondisi lapangan',
      label: 'Kondisi sebenarnya di lokasi',
      hint: 'Tinggi air, jumlah korban, akses jalan, kebutuhan bantuan',
      confirm: 'Kirim',
      maxLines: 4,
    );
    if (text == null || !mounted) return;
    final err = AppState.instance.addFieldReport(r, text);
    snack(context, err ?? 'Laporan lapangan tercatat.');
  }

  Future<void> _assign(Report r) async {
    final s = AppState.instance;
    final list = s.assignablePetugas(r);
    if (list.isEmpty) {
      snack(context, 'Belum ada Petugas Lapangan aktif di wilayah laporan ini.');
      return;
    }
    final picked = await showDialog<AppUser>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Tugaskan ke petugas'),
        children: [
          for (final p in list)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p),
              child: Text('${p.name} - ${Regions.shortName(p.areaId)}'),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    final err = s.assignReport(r, picked);
    snack(context, err ?? 'Ditugaskan kepada ${picked.name}.');
  }

  void _sendComment(Report r) {
    if (_comment.text.trim().isEmpty) return;
    AppState.instance.addComment(r, _comment.text);
    _comment.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        final r = s.reportById(widget.reportId);
        if (r == null || !s.loggedIn) {
          return Scaffold(
            appBar: AppBar(title: const Text('Laporan')),
            body: const EmptyState(
                icon: Icons.search_off, text: 'Laporan tidak ditemukan.'),
          );
        }
        final info = categoryInfo(r.category);
        final canMod = s.canModerate(r);
        final canHandle = s.canHandle(r);
        final confirmed = r.confirmedBy.contains(s.me.email);
        final canConfirm = s.canConfirm(r);
        final evac = s.evacuationFor(r.areaId);

        return Scaffold(
          appBar: AppBar(title: Text(r.category)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: severityColor(r.severity),
                    child: Icon(info.icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.location,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          Regions.fullName(r.areaId),
                          style: const TextStyle(fontSize: 12, color: kGray),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  StatusChip(
                      label: r.severity.label,
                      color: severityColor(r.severity)),
                  StatusChip(
                      label: r.status.label, color: statusColor(r.status)),
                  if (r.pendingSync)
                    const StatusChip(label: 'Menunggu sinkron', color: kYellow),
                  if (r.assigneeName != null)
                    StatusChip(
                        label: 'Petugas: ${r.assigneeName}', color: kPurple),
                ],
              ),
              if (r.photoPath != null) ...[
                const SizedBox(height: 12),
                PhotoThumb(path: r.photoPath, height: 220),
              ],
              const SizedBox(height: 12),
              Text(r.description),
              const SizedBox(height: 4),
              Text(
                'Dilaporkan ${r.authorName} - ${timeAgo(r.createdAt)}',
                style: const TextStyle(fontSize: 12, color: kGray),
              ),
              if (r.hasCoordinates)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, size: 16, color: kBlue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${formatCoord(r.lat!, r.lng!)}'
                          '${r.accuracyM == null ? '' : ' (akurasi ${r.accuracyM!.round()} m)'}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Salin koordinat',
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text: formatCoord(r.lat!, r.lng!)));
                          snack(context, 'Koordinat disalin.');
                        },
                      ),
                    ],
                  ),
                ),
              if (r.status == ReportStatus.ditolak && r.rejectReason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Alasan ditolak: ${r.rejectReason}',
                      style: const TextStyle(color: kRed)),
                ),
              const SectionTitle('Riwayat penanganan'),
              _Timeline(report: r),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.groups, color: kTeal),
                  title: Text('${r.confirmations} warga mengonfirmasi'),
                  subtitle: Text(
                    !confirmed &&
                            !canConfirm &&
                            r.status.isActive
                        ? 'Konfirmasi hanya untuk warga satu kelurahan dengan lokasi kejadian.'
                        : r.status == ReportStatus.menunggu
                            ? 'Terverifikasi otomatis bila mencapai ${AppState.autoVerifyThreshold} konfirmasi.'
                            : 'Konfirmasi membantu pengurus menilai kebenaran laporan.',
                  ),
                  trailing: FilledButton(
                    onPressed: !canConfirm
                        ? null
                        : () {
                            s.confirmReport(r);
                            snack(context, 'Terima kasih, konfirmasi tercatat.');
                          },
                    child: Text(confirmed ? 'Sudah' : 'Saya lihat'),
                  ),
                ),
              ),
              if (canHandle && r.status.isActive) ...[
                const SectionTitle('Tindakan'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canMod && r.status == ReportStatus.menunggu) ...[
                      FilledButton.icon(
                        onPressed: () => _verify(r),
                        icon: const Icon(Icons.verified),
                        label: const Text('Verifikasi'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _reject(r),
                        icon: const Icon(Icons.block),
                        label: const Text('Tolak'),
                      ),
                    ],
                    if (s.isPetugas &&
                        r.assigneeEmail == null &&
                        r.status != ReportStatus.menunggu)
                      OutlinedButton.icon(
                        onPressed: () {
                          final err = s.claimTask(r);
                          snack(context, err ?? 'Tugas Anda. Segera ditangani.');
                        },
                        icon: const Icon(Icons.assignment_ind),
                        label: const Text('Ambil tugas'),
                      ),
                    if (s.canAssign(r))
                      OutlinedButton.icon(
                        onPressed: () => _assign(r),
                        icon: const Icon(Icons.person_add_alt),
                        label: Text(r.assigneeName == null
                            ? 'Tugaskan petugas'
                            : 'Ganti petugas'),
                      ),
                    if (r.status == ReportStatus.terverifikasi)
                      FilledButton.icon(
                        onPressed: () {
                          s.setStatus(r, ReportStatus.diproses);
                          snack(context, 'Status: sedang diproses.');
                        },
                        icon: const Icon(Icons.engineering),
                        label: const Text('Mulai ditangani'),
                      ),
                    if (r.status == ReportStatus.terverifikasi ||
                        r.status == ReportStatus.diproses)
                      FilledButton.icon(
                        onPressed: () {
                          s.setStatus(r, ReportStatus.selesai);
                          snack(context, 'Ditandai selesai.');
                        },
                        icon: const Icon(Icons.task_alt),
                        label: const Text('Tandai selesai'),
                      ),
                    if (r.status != ReportStatus.menunggu)
                      OutlinedButton.icon(
                        onPressed: () => _fieldReport(r),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('Lapor kondisi lapangan'),
                      ),
                  ],
                ),
              ] else if (s.isResponder && !canHandle)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Laporan ini di luar wilayah Anda, jadi hanya bisa dilihat.',
                    style: TextStyle(fontSize: 12, color: kGray),
                  ),
                ),
              if (evac.isNotEmpty) ...[
                const SectionTitle('Posko terdekat'),
                for (final p in evac.take(2))
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.home_work, color: poskoColor(p.state)),
                      title: Text(p.name),
                      subtitle: Text(
                          '${p.address} - ${p.state.label}, sisa ${p.remaining} tempat'),
                    ),
                  ),
              ],
              const SectionTitle('Komentar dan pembaruan'),
              if (r.comments.isEmpty)
                const Text('Belum ada komentar.',
                    style: TextStyle(color: kGray)),
              for (final c in r.comments)
                Card(
                  color: c.field
                      ? const Color(0xFFEFE6F5)
                      : (c.official ? const Color(0xFFE6F4F1) : null),
                  child: ListTile(
                    leading: Icon(
                      c.field
                          ? Icons.engineering
                          : (c.official
                              ? Icons.verified_user
                              : Icons.person_outline),
                      color: c.field
                          ? kPurple
                          : (c.official ? kTeal : kGray),
                    ),
                    title: Text(
                        c.field ? '${c.author} - kondisi lapangan' : c.author,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(c.text),
                    trailing: Text(timeAgo(c.createdAt),
                        style: const TextStyle(fontSize: 11, color: kGray)),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _comment,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(r),
                      decoration:
                          const InputDecoration(hintText: 'Tulis komentar...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Kirim komentar',
                    onPressed: () => _sendComment(r),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Riwayat (audit trail): siapa melakukan apa dan kapan, dari pelapor,
/// pemverifikasi RT, sampai petugas lapangan.
class _Timeline extends StatelessWidget {
  final Report report;
  const _Timeline({required this.report});

  @override
  Widget build(BuildContext context) {
    final events = [...report.timeline]
      ..sort((a, b) => a.at.compareTo(b.at));
    if (events.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Belum ada riwayat.', style: TextStyle(color: kGray)),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          children: [
            for (var i = 0; i < events.length; i++)
              _row(events[i], isLast: i == events.length - 1),
          ],
        ),
      ),
    );
  }

  Widget _row(TimelineEvent e, {required bool isLast}) {
    final color = e.status == null ? kGray : statusColor(e.status!);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 3),
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFFDCE1E6)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.action,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${e.actor} (${e.role}) - ${dateTimeLabel(e.at)}',
                    style: const TextStyle(fontSize: 12, color: kGray),
                  ),
                  if (e.note != null && e.note!.isNotEmpty)
                    Text(e.note!, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
