import 'models.dart';

enum RecapPeriod { semua, hari7, hari30 }

extension RecapPeriodX on RecapPeriod {
  String get label => switch (this) {
        RecapPeriod.semua => 'Semua waktu',
        RecapPeriod.hari7 => '7 hari terakhir',
        RecapPeriod.hari30 => '30 hari terakhir',
      };

  int? get days => switch (this) {
        RecapPeriod.semua => null,
        RecapPeriod.hari7 => 7,
        RecapPeriod.hari30 => 30,
      };
}

class DayCount {
  final DateTime day;
  final int count;
  const DayCount(this.day, this.count);
}

/// Rekapitulasi laporan (murni logika, dipakai layar statistik dan ekspor).
class ReportRecap {
  final List<Report> reports;
  final int total;
  final Map<ReportStatus, int> byStatus;
  final Map<Severity, int> bySeverity;

  /// Kategori -> jumlah per tingkat bahaya, urut dari terbanyak.
  final List<MapEntry<String, Map<Severity, int>>> byCategory;
  final int? avgVerifyMinutes;
  final int? avgResolveMinutes;

  /// Jumlah laporan per hari untuk [trendDays] hari terakhir (terlama dulu).
  final List<DayCount> perDay;

  ReportRecap._({
    required this.reports,
    required this.total,
    required this.byStatus,
    required this.bySeverity,
    required this.byCategory,
    required this.avgVerifyMinutes,
    required this.avgResolveMinutes,
    required this.perDay,
  });

  factory ReportRecap.of(
    List<Report> reports, {
    int trendDays = 7,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final byStatus = <ReportStatus, int>{
      for (final s in ReportStatus.values) s: 0,
    };
    final bySeverity = <Severity, int>{
      for (final s in Severity.values) s: 0,
    };
    final cats = <String, Map<Severity, int>>{};
    for (final r in reports) {
      byStatus[r.status] = (byStatus[r.status] ?? 0) + 1;
      bySeverity[r.severity] = (bySeverity[r.severity] ?? 0) + 1;
      final m = cats.putIfAbsent(
        r.category,
        () => <Severity, int>{for (final s in Severity.values) s: 0},
      );
      m[r.severity] = (m[r.severity] ?? 0) + 1;
    }
    int sum(Map<Severity, int> m) => m.values.fold(0, (a, b) => a + b);
    final sorted = cats.entries.toList()
      ..sort((a, b) {
        final c = sum(b.value).compareTo(sum(a.value));
        return c != 0 ? c : a.key.compareTo(b.key);
      });

    int? avg(Iterable<int> xs) {
      final list = xs.toList();
      if (list.isEmpty) return null;
      return (list.reduce((a, b) => a + b) / list.length).round();
    }

    final verify = avg(reports
        .where((r) => r.verifiedAt != null)
        .map((r) => r.verifiedAt!.difference(r.createdAt).inMinutes));
    final resolve = avg(reports
        .where((r) => r.resolvedAt != null)
        .map((r) => r.resolvedAt!.difference(r.createdAt).inMinutes));

    final base = DateTime(today.year, today.month, today.day);
    final perDay = <DayCount>[];
    for (var i = trendDays - 1; i >= 0; i--) {
      final d = base.subtract(Duration(days: i));
      final n = reports
          .where((r) =>
              r.createdAt.year == d.year &&
              r.createdAt.month == d.month &&
              r.createdAt.day == d.day)
          .length;
      perDay.add(DayCount(d, n));
    }

    return ReportRecap._(
      reports: reports,
      total: reports.length,
      byStatus: byStatus,
      bySeverity: bySeverity,
      byCategory: sorted,
      avgVerifyMinutes: verify,
      avgResolveMinutes: resolve,
      perDay: perDay,
    );
  }

  int categoryTotal(Map<Severity, int> m) =>
      m.values.fold(0, (a, b) => a + b);

  int get maxCategoryTotal =>
      byCategory.isEmpty ? 1 : categoryTotal(byCategory.first.value);

  int get maxPerDay {
    var m = 1;
    for (final d in perDay) {
      if (d.count > m) m = d.count;
    }
    return m;
  }
}

/// Menyaring laporan menurut periode (berdasarkan waktu pembuatan).
List<Report> filterByPeriod(List<Report> list, RecapPeriod p, {DateTime? now}) {
  final days = p.days;
  if (days == null) return list;
  final since = (now ?? DateTime.now()).subtract(Duration(days: days));
  return list.where((r) => r.createdAt.isAfter(since)).toList();
}
