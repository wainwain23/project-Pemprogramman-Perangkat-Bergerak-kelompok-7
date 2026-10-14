import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'report_detail_screen.dart';
import 'report_form_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportScope _scope = ReportScope.kelurahan;
  ReportStatus? _status;
  String? _category;
  bool _mine = false;
  bool _byPriority = false;
  bool _searching = false;
  String _query = '';

  List<Report> _apply(List<Report> input) {
    var list = input;
    if (_status != null) list = list.where((r) => r.status == _status).toList();
    if (_category != null) {
      list = list.where((r) => r.category == _category).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((r) =>
              r.description.toLowerCase().contains(q) ||
              r.location.toLowerCase().contains(q) ||
              r.category.toLowerCase().contains(q))
          .toList();
    }
    if (_byPriority) {
      // Tingkat bahaya tertinggi dulu, lalu yang terbaru.
      list = [...list]..sort((a, b) {
          final c = b.severity.index.compareTo(a.severity.index);
          return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        // Hanya tampilkan cakupan yang berlaku untuk wilayah pengguna.
        final scopes = s.availableScopes;
        final scope = scopes.contains(_scope) ? _scope : scopes.first;
        final list = _apply(_mine ? s.myReports : s.reportsInScope(scope));
        final areaId = s.scopeAreaId(scope);
        final ts = textScaleOf(context);

        return Scaffold(
          appBar: AppBar(
            title: _searching
                ? TextField(
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      hintText: 'Cari laporan...',
                      hintStyle: TextStyle(color: Color(0xFFBFD0E0)),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  )
                : const Text('Laporan Warga'),
            actions: [
              IconButton(
                tooltip: _searching ? 'Tutup pencarian' : 'Cari',
                icon: Icon(_searching ? Icons.close : Icons.search),
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _query = '';
                }),
              ),
              PopupMenuButton<bool>(
                tooltip: 'Urutkan',
                icon: const Icon(Icons.sort),
                onSelected: (v) => setState(() => _byPriority = v),
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(
                    value: false,
                    checked: !_byPriority,
                    child: const Text('Terbaru'),
                  ),
                  CheckedPopupMenuItem(
                    value: true,
                    checked: _byPriority,
                    child: const Text('Prioritas tertinggi'),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: kRed,
            foregroundColor: Colors.white,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const ReportFormScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Lapor'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Di wilayah')),
                    ButtonSegment(value: true, label: Text('Laporan saya')),
                  ],
                  selected: {_mine},
                  onSelectionChanged: (v) => setState(() => _mine = v.first),
                ),
              ),
              if (!_mine) ...[
                SizedBox(
                  height: 52 * ts,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final sc in scopes)
                        Padding(
                          padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                          child: ChoiceChip(
                            label: Text(sc.label),
                            selected: scope == sc,
                            onSelected: (_) => setState(() => _scope = sc),
                          ),
                        ),
                    ],
                  ),
                ),
                if (areaId != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Menampilkan: ${Regions.fullName(areaId)}',
                        style: const TextStyle(fontSize: 12, color: kGray),
                      ),
                    ),
                  ),
              ],
              SizedBox(
                height: 52 * ts,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                      child: FilterChip(
                        label: const Text('Semua'),
                        selected: _status == null,
                        onSelected: (_) => setState(() => _status = null),
                      ),
                    ),
                    for (final st in ReportStatus.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                        child: FilterChip(
                          label: Text(st.shortLabel),
                          selected: _status == st,
                          onSelected: (_) => setState(
                              () => _status = _status == st ? null : st),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 48 * ts,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final c in kCategories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 8),
                        child: FilterChip(
                          avatar: Icon(c.icon, size: 16),
                          label: Text(c.name),
                          selected: _category == c.name,
                          onSelected: (_) => setState(
                              () => _category = _category == c.name ? null : c.name),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.inbox_outlined,
                        text: 'Belum ada laporan yang cocok dengan filter ini.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _ReportCard(report: list[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Report report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final r = report;
    final info = categoryInfo(r.category);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => ReportDetailScreen(reportId: r.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: severityColor(r.severity),
                child: Icon(info.icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.category} - ${r.location}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(
                          label: r.status.label,
                          color: statusColor(r.status),
                        ),
                        if (r.pendingSync)
                          const StatusChip(
                              label: 'Menunggu sinkron', color: kYellow),
                        Text(
                          '${Regions.shortName(r.areaId)} - ${timeAgo(r.createdAt)} - ${r.confirmations} konfirmasi',
                          style: const TextStyle(fontSize: 11, color: kGray),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
