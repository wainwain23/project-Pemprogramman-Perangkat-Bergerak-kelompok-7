import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Persetujuan akun pengurus (Ketua RT, Petugas Lapangan, Relawan).
/// Admin Wilayah memutuskan semua peran di wilayahnya; Ketua RT hanya
/// Relawan di RT-nya; Super Admin semuanya.
class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  Future<void> _reject(BuildContext context, AppUser u) async {
    final reason = await promptText(
      context,
      title: 'Tolak pendaftaran ${u.name}',
      label: 'Alasan penolakan',
      hint: 'Contoh: bukti SK tidak sesuai',
      confirm: 'Tolak',
      maxLines: 2,
    );
    if (reason == null || !context.mounted) return;
    final err = AppState.instance.rejectAccount(u, reason);
    snack(context, err ?? 'Pendaftaran ${u.name} ditolak.');
  }

  Future<void> _approve(BuildContext context, AppUser u) async {
    final ok = await confirmDialog(
      context,
      title: 'Setujui ${u.role.label}?',
      text: '${u.name} akan mendapat hak ${u.role.label} untuk '
          '${Regions.shortName(AppState.instance.authorityAreaOf(u))}.',
      confirm: 'Setujui',
    );
    if (!ok || !context.mounted) return;
    AppState.instance.approve(u);
    snack(context, '${u.name} disetujui sebagai ${u.role.label}.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        final list = s.pendingApprovals;
        return Scaffold(
          appBar: AppBar(title: const Text('Persetujuan Akun')),
          body: list.isEmpty
              ? const EmptyState(
                  icon: Icons.how_to_reg,
                  text: 'Tidak ada permintaan yang menunggu.')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Periksa bukti (SK atau surat pengantar) dan hubungi pendaftar bila perlu sebelum menyetujui, agar tidak ada yang menyamar.',
                      style: TextStyle(fontSize: 12, color: kGray),
                    ),
                    const SizedBox(height: 8),
                    for (final u in list)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: kYellow,
                                    child:
                                        Icon(Icons.badge, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(u.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        Text(u.email,
                                            style: const TextStyle(
                                                fontSize: 12, color: kGray)),
                                      ],
                                    ),
                                  ),
                                  StatusChip(label: u.role.label, color: kBlue),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.place,
                                      size: 16, color: kRed),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text(Regions.fullName(u.areaId),
                                          style:
                                              const TextStyle(fontSize: 13))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone,
                                      size: 16, color: kGray),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text(u.phone,
                                          style:
                                              const TextStyle(fontSize: 13))),
                                  TextButton(
                                    onPressed: () =>
                                        callPhone(context, u.phone),
                                    child: const Text('Hubungi'),
                                  ),
                                ],
                              ),
                              Text('Mendaftar ${timeAgo(u.createdAt)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: kGray)),
                              const SizedBox(height: 10),
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
                                      onPressed: () => _approve(context, u),
                                      child: const Text('Setujui'),
                                    ),
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
