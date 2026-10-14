import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../geo.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'report_detail_screen.dart';

/// Tugas Petugas Lapangan: yang ditugaskan kepadanya dan yang masih bisa
/// diambil di wilayah kewenangannya.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tugas Lapangan'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFBFD0E0),
            tabs: [Tab(text: 'Tugas saya'), Tab(text: 'Bisa diambil')],
          ),
        ),
        body: ListenableBuilder(
          listenable: AppState.instance,
          builder: (context, _) {
            final s = AppState.instance;
            if (!s.loggedIn || !s.isPetugas) {
              return const EmptyState(
                  icon: Icons.lock_outline,
                  text: 'Menu ini untuk Petugas Lapangan yang sudah disetujui.');
            }
            return TabBarView(
              children: [
                _TaskList(
                  reports: s.myTasks,
                  empty: 'Tidak ada tugas yang sedang Anda tangani.',
                  claimable: false,
                ),
                _TaskList(
                  reports: s.availableTasks,
                  empty: 'Tidak ada laporan terverifikasi yang menunggu petugas.',
                  claimable: true,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final List<Report> reports;
  final String empty;
  final bool claimable;
  const _TaskList(
      {required this.reports, required this.empty, required this.claimable});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return EmptyState(icon: Icons.assignment_turned_in, text: empty);
    }
    final s = AppState.instance;
    final ref = s.myReferencePoint;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final r in reports)
          Card(
            key: ValueKey(r.id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: severityColor(r.severity),
                        child: Icon(categoryInfo(r.category).icon,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${r.category} - ${r.location}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                              '${Regions.shortName(r.areaId)} - ${timeAgo(r.createdAt)}'
                              '${r.hasCoordinates && ref != null ? ' - ${formatDistance(haversineM(ref.lat, ref.lng, r.lat!, r.lng!))} dari Anda' : ''}',
                              style: const TextStyle(
                                  fontSize: 12, color: kGray),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(
                          label: r.severity.label,
                          color: severityColor(r.severity)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(r.description,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      StatusChip(
                          label: r.status.label,
                          color: statusColor(r.status)),
                      OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  ReportDetailScreen(reportId: r.id)),
                        ),
                        child: const Text('Buka'),
                      ),
                      if (claimable)
                        FilledButton(
                          onPressed: () {
                            final err = s.claimTask(r);
                            snack(context, err ?? 'Tugas diambil.');
                          },
                          child: const Text('Ambil tugas'),
                        )
                      else if (r.status == ReportStatus.terverifikasi)
                        FilledButton(
                          onPressed: () {
                            s.setStatus(r, ReportStatus.diproses);
                            snack(context, 'Status: sedang diproses.');
                          },
                          child: const Text('Mulai'),
                        )
                      else if (r.status == ReportStatus.diproses)
                        FilledButton(
                          onPressed: () {
                            s.setStatus(r, ReportStatus.selesai);
                            snack(context, 'Ditandai selesai.');
                          },
                          child: const Text('Selesai'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
