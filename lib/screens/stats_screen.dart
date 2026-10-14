import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../models.dart';
import '../recap.dart';
import '../services/export_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/region_picker.dart';

/// Statistik dan rekapitulasi kejadian per wilayah, dengan ekspor PDF/Excel
/// untuk laporan resmi (Ketua RT, Admin, Petugas, Super Admin).
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  ReportScope _scope = ReportScope.kelurahan;
  RecapPeriod _period = RecapPeriod.hari30;
  String? _pickedArea; // hanya Super Admin
  bool _exporting = false;
  int _pickerGen = 0;

  /// Wilayah dan label cakupan yang sedang ditampilkan.
  (String area, String scopeLabel) _target(AppState s, ReportScope scope) {
    if (s.isSuperAdmin) {
      final a = _pickedArea ?? Regions.rootId;
      final level = Regions.levelOf(a);
      return (a, level == null ? 'Nasional' : level.label);
    }
    return (s.scopeAreaId(scope) ?? s.myAuthorityArea, scope.label);
  }

  List<Report> _reportsFor(AppState s, ReportScope scope, String area) {
    if (s.isSuperAdmin) {
      final out = s.reports
          .where((r) => Regions.isWithin(r.areaId, area))
          .toList();
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    }
    return s.reportsInScope(scope);
  }

  Future<void> _export(
      {required bool pdf,
      required RecapMeta meta,
      required ReportRecap recap}) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final base = recapFileBase(meta);
      if (pdf) {
        final bytes = await buildRecapPdf(meta, recap);
        await ExportService.share(bytes, '$base.pdf', ExportService.pdfMime,
            subject: 'Rekapitulasi kejadian bencana - ${meta.areaName}');
      } else {
        final bytes = buildRecapXlsx(meta, recap);
        await ExportService.share(bytes, '$base.xlsx', ExportService.xlsxMime,
            subject: 'Rekapitulasi kejadian bencana - ${meta.areaName}');
      }
    } catch (_) {
      if (mounted) {
        snack(context, 'Gagal membuat atau membagikan berkas. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        if (!s.loggedIn) return const SizedBox.shrink();
        final scopes = s.availableScopes;
        final scope = scopes.contains(_scope)
            ? _scope
            : (scopes.isEmpty ? ReportScope.kelurahan : scopes.first);
        final (area, scopeLabel) = _target(s, scope);
        final all = _reportsFor(s, scope, area);
        final list = filterByPeriod(all, _period);
        final trendDays = _period == RecapPeriod.hari30 ? 30 : 7;
        final recap = ReportRecap.of(list, trendDays: trendDays);
        final meta = RecapMeta(
          areaName: Regions.fullName(area),
          scopeLabel: scopeLabel,
          periodLabel: _period.label,
          generatedBy: '${s.me.name} (${s.me.role.label})',
          generatedAt: DateTime.now(),
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Statistik Wilayah')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (s.isSuperAdmin)
                Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.place, color: kRed),
                    title: const Text('Wilayah'),
                    subtitle: Text(Regions.fullName(area)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      RegionPicker(
                        key: ValueKey('stats-picker-$_pickerGen'),
                        initialId: _pickedArea,
                        minLevel: RegionLevel.provinsi,
                        onChanged: (id) => setState(() => _pickedArea = id),
                      ),
                      if (_pickedArea != null)
                        TextButton(
                          onPressed: () => setState(() {
                            _pickedArea = null;
                            _pickerGen++;
                          }),
                          child: const Text('Tampilkan seluruh Indonesia'),
                        ),
                    ],
                  ),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  children: [
                    for (final sc in scopes)
                      ChoiceChip(
                        label: Text(sc.label),
                        selected: scope == sc,
                        onSelected: (_) => setState(() => _scope = sc),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(Regions.fullName(area),
                      style: const TextStyle(fontSize: 12, color: kGray)),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in RecapPeriod.values)
                    ChoiceChip(
                      label: Text(p.label),
                      selected: _period == p,
                      onSelected: (_) => setState(() => _period = p),
                    ),
                ],
              ),
              const SectionTitle('Ringkasan'),
              Row(
                children: [
                  _Box('Total', recap.total, kNavy),
                  _Box('Menunggu', recap.byStatus[ReportStatus.menunggu] ?? 0,
                      kGray),
                  _Box('Terverifikasi',
                      recap.byStatus[ReportStatus.terverifikasi] ?? 0, kTeal),
                  _Box('Diproses', recap.byStatus[ReportStatus.diproses] ?? 0,
                      kPurple),
                  _Box('Selesai', recap.byStatus[ReportStatus.selesai] ?? 0,
                      kBlue),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final sv in Severity.values.reversed)
                    _Box('Tingkat ${sv.label}', recap.bySeverity[sv] ?? 0,
                        severityColor(sv)),
                  _Box('Ditolak', recap.byStatus[ReportStatus.ditolak] ?? 0,
                      kRed),
                ],
              ),
              const SizedBox(height: 4),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.timer_outlined, color: kTeal),
                  title: const Text('Rata-rata waktu verifikasi'),
                  trailing: Text(
                    recap.avgVerifyMinutes == null
                        ? '-'
                        : '${recap.avgVerifyMinutes} menit',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.task_alt, color: kBlue),
                  title: const Text('Rata-rata waktu penyelesaian'),
                  trailing: Text(
                    recap.avgResolveMinutes == null
                        ? '-'
                        : '${recap.avgResolveMinutes} menit',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SectionTitle('Per kategori dan tingkat bahaya'),
              if (recap.byCategory.isEmpty)
                const Text('Belum ada data.', style: TextStyle(color: kGray)),
              for (final e in recap.byCategory)
                _CategoryBar(
                  name: e.key,
                  counts: e.value,
                  total: recap.categoryTotal(e.value),
                  max: recap.maxCategoryTotal,
                ),
              if (recap.byCategory.isNotEmpty)
                Wrap(
                  spacing: 12,
                  children: [
                    for (final sv in Severity.values.reversed)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.square_rounded,
                            size: 12, color: severityColor(sv)),
                        const SizedBox(width: 4),
                        Text(sv.label, style: const TextStyle(fontSize: 12)),
                      ]),
                  ],
                ),
              SectionTitle('Tren $trendDays hari terakhir'),
              _TrendChart(days: recap.perDay, max: recap.maxPerDay),
              if (s.canExport) ...[
                const SectionTitle('Ekspor laporan resmi'),
                Text(
                  'Rekap ${_period.label.toLowerCase()} untuk ${Regions.label(area)} '
                  '(${recap.total} laporan). Berkas dibuat di perangkat lalu dibagikan lewat menu bagikan.',
                  style: const TextStyle(fontSize: 12, color: kGray),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exporting || recap.total == 0
                            ? null
                            : () => _export(pdf: true, meta: meta, recap: recap),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _exporting || recap.total == 0
                            ? null
                            : () => _export(pdf: false, meta: meta, recap: recap),
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Excel'),
                      ),
                    ),
                  ],
                ),
                if (_exporting)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (recap.total == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Tidak ada laporan pada periode ini.',
                        style: TextStyle(fontSize: 12, color: kGray)),
                  ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _Box extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Box(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Column(
            children: [
              Text('$value',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: kGray)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Batang bertumpuk: panjang menurut jumlah laporan, warna menurut tingkat.
class _CategoryBar extends StatelessWidget {
  final String name;
  final Map<Severity, int> counts;
  final int total;
  final int max;
  const _CategoryBar({
    required this.name,
    required this.counts,
    required this.total,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final detail = [
      for (final sv in Severity.values.reversed)
        if ((counts[sv] ?? 0) > 0) '${sv.label} ${counts[sv]}',
    ].join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: '$name: $total laporan ($detail)',
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(name, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                final width = box.maxWidth * (total / max);
                return Align(
                  alignment: Alignment.centerLeft,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: width < 6 ? 6 : width,
                      height: 16,
                      child: Row(
                        children: [
                          for (final sv in Severity.values.reversed)
                            if ((counts[sv] ?? 0) > 0)
                              Expanded(
                                flex: counts[sv]!,
                                child: Container(color: severityColor(sv)),
                              ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(
              width: 32,
              child: Text('$total', textAlign: TextAlign.right),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grafik batang jumlah laporan per hari.
class _TrendChart extends StatelessWidget {
  final List<DayCount> days;
  final int max;
  const _TrendChart({required this.days, required this.max});

  static const _names = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final compact = days.length > 10;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: Semantics(
                    label: '${dateLabel(days[i].day)}: ${days[i].count} laporan',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!compact || days[i].count > 0)
                          Text('${days[i].count}',
                              style: const TextStyle(fontSize: 10)),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          height: 90 * days[i].count / max,
                          decoration: BoxDecoration(
                            color: days[i].count == 0
                                ? const Color(0xFFDCE1E6)
                                : kRed,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          constraints: const BoxConstraints(minHeight: 2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          compact
                              ? (i % 5 == 0 ? '${days[i].day.day}' : '')
                              : _names[days[i].day.weekday - 1],
                          style: const TextStyle(fontSize: 10, color: kGray),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
