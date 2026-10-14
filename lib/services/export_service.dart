import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../data/regions.dart';
import '../models.dart';
import '../recap.dart';

/// Keterangan laporan resmi (kop dokumen).
class RecapMeta {
  final String areaName;
  final String scopeLabel;
  final String periodLabel;
  final String generatedBy;
  final DateTime generatedAt;
  const RecapMeta({
    required this.areaName,
    required this.scopeLabel,
    required this.periodLabel,
    required this.generatedBy,
    required this.generatedAt,
  });
}

String _coord(Report r) => r.hasCoordinates
    ? '${r.lat!.toStringAsFixed(5)}, ${r.lng!.toStringAsFixed(5)}'
    : '-';

String _minutes(int? m) => m == null ? '-' : '$m menit';

/// Nama berkas aman: huruf, angka, strip, garis bawah.
String safeFileName(String s) =>
    s.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_').replaceAll(RegExp(r'_+'), '_');

String recapFileBase(RecapMeta meta) {
  final d = meta.generatedAt;
  final stamp = '${d.year}${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';
  return 'rekap_bencana_${safeFileName(meta.areaName)}_$stamp';
}

/// Membuat PDF rekapitulasi kejadian bencana untuk laporan administratif.
Future<Uint8List> buildRecapPdf(RecapMeta meta, ReportRecap recap) async {
  final doc = pw.Document(
    title: 'Rekapitulasi Kejadian Bencana - ${meta.areaName}',
    author: 'Warga Siaga',
  );

  pw.Widget cell(String text, {bool bold = false, pw.TextAlign? align}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  pw.Widget table(
    List<String> header,
    List<List<String>> rows, {
    Map<int, pw.TableColumnWidth>? widths,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
      columnWidths: widths,
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [for (final h in header) cell(h, bold: true)],
        ),
        for (final r in rows) pw.TableRow(children: [for (final c in r) cell(c)]),
      ],
    );
  }

  pw.Widget heading(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(
          t,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );

  final statusRows = [
    for (final s in ReportStatus.values)
      [s.label, '${recap.byStatus[s] ?? 0}'],
    ['Total laporan', '${recap.total}'],
    ['Rata-rata waktu verifikasi', _minutes(recap.avgVerifyMinutes)],
    ['Rata-rata waktu penyelesaian', _minutes(recap.avgResolveMinutes)],
  ];

  final categoryRows = [
    for (final e in recap.byCategory)
      [
        e.key,
        '${e.value[Severity.info] ?? 0}',
        '${e.value[Severity.waspada] ?? 0}',
        '${e.value[Severity.bahaya] ?? 0}',
        '${recap.categoryTotal(e.value)}',
      ],
  ];

  final dayRows = [
    for (final d in recap.perDay) [dateLabel(d.day), '${d.count}'],
  ];

  final reportRows = [
    for (var i = 0; i < recap.reports.length; i++)
      [
        '${i + 1}',
        dateTimeLabel(recap.reports[i].createdAt),
        recap.reports[i].category,
        recap.reports[i].location,
        Regions.shortName(recap.reports[i].areaId),
        recap.reports[i].severity.label,
        recap.reports[i].status.label,
        _coord(recap.reports[i]),
      ],
  ];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Dibuat oleh aplikasi Warga Siaga',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(
            'Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
      build: (ctx) => [
        pw.Text(
          'REKAPITULASI KEJADIAN BENCANA',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Wilayah: ${meta.areaName}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Cakupan: ${meta.scopeLabel}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Periode: ${meta.periodLabel}', style: const pw.TextStyle(fontSize: 10)),
        pw.Text(
          'Dicetak: ${dateTimeLabel(meta.generatedAt)} oleh ${meta.generatedBy}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Divider(),
        heading('1. Ringkasan'),
        table(['Keterangan', 'Jumlah'], statusRows,
            widths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)}),
        heading('2. Jumlah laporan per kategori dan tingkat bahaya'),
        if (categoryRows.isEmpty)
          pw.Text('Belum ada data.', style: const pw.TextStyle(fontSize: 9))
        else
          table(['Kategori', 'Info', 'Waspada', 'Bahaya', 'Total'], categoryRows),
        heading('3. Tren harian'),
        table(['Tanggal', 'Jumlah laporan'], dayRows),
        heading('4. Daftar laporan'),
        if (reportRows.isEmpty)
          pw.Text('Belum ada laporan.', style: const pw.TextStyle(fontSize: 9))
        else
          table(
            [
              'No',
              'Waktu',
              'Kategori',
              'Lokasi',
              'Wilayah',
              'Tingkat',
              'Status',
              'Koordinat'
            ],
            reportRows,
            widths: {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(3),
              4: const pw.FlexColumnWidth(3),
              5: const pw.FlexColumnWidth(1.5),
              6: const pw.FlexColumnWidth(2),
              7: const pw.FlexColumnWidth(2.5),
            },
          ),
      ],
    ),
  );
  return doc.save();
}

/// Membuat berkas Excel (.xlsx) dengan tiga lembar: Ringkasan, Per Kategori,
/// Daftar Laporan.
List<int> buildRecapXlsx(RecapMeta meta, ReportRecap recap) {
  final excel = Excel.createExcel();

  void boldRow(Sheet sheet, int row, int columns) {
    for (var c = 0; c < columns; c++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row))
          .cellStyle = CellStyle(bold: true);
    }
  }

  final summary = excel['Ringkasan'];
  summary.appendRow([TextCellValue('REKAPITULASI KEJADIAN BENCANA')]);
  summary.appendRow([TextCellValue('Wilayah'), TextCellValue(meta.areaName)]);
  summary.appendRow([TextCellValue('Cakupan'), TextCellValue(meta.scopeLabel)]);
  summary.appendRow([TextCellValue('Periode'), TextCellValue(meta.periodLabel)]);
  summary.appendRow([
    TextCellValue('Dicetak'),
    TextCellValue('${dateTimeLabel(meta.generatedAt)} oleh ${meta.generatedBy}'),
  ]);
  summary.appendRow([TextCellValue('')]);
  summary.appendRow([TextCellValue('Status'), TextCellValue('Jumlah')]);
  boldRow(summary, 0, 1);
  boldRow(summary, 6, 2);
  for (final s in ReportStatus.values) {
    summary.appendRow([
      TextCellValue(s.label),
      IntCellValue(recap.byStatus[s] ?? 0),
    ]);
  }
  summary.appendRow([TextCellValue('Total laporan'), IntCellValue(recap.total)]);
  summary.appendRow([
    TextCellValue('Rata-rata waktu verifikasi'),
    TextCellValue(_minutes(recap.avgVerifyMinutes)),
  ]);
  summary.appendRow([
    TextCellValue('Rata-rata waktu penyelesaian'),
    TextCellValue(_minutes(recap.avgResolveMinutes)),
  ]);

  final cats = excel['Per Kategori'];
  cats.appendRow([
    TextCellValue('Kategori'),
    TextCellValue('Info'),
    TextCellValue('Waspada'),
    TextCellValue('Bahaya'),
    TextCellValue('Total'),
  ]);
  boldRow(cats, 0, 5);
  for (final e in recap.byCategory) {
    cats.appendRow([
      TextCellValue(e.key),
      IntCellValue(e.value[Severity.info] ?? 0),
      IntCellValue(e.value[Severity.waspada] ?? 0),
      IntCellValue(e.value[Severity.bahaya] ?? 0),
      IntCellValue(recap.categoryTotal(e.value)),
    ]);
  }

  final list = excel['Daftar Laporan'];
  list.appendRow([
    TextCellValue('No'),
    TextCellValue('Waktu'),
    TextCellValue('Kategori'),
    TextCellValue('Lokasi'),
    TextCellValue('Wilayah'),
    TextCellValue('Tingkat'),
    TextCellValue('Status'),
    TextCellValue('Latitude'),
    TextCellValue('Longitude'),
    TextCellValue('Pelapor'),
    TextCellValue('Deskripsi'),
  ]);
  boldRow(list, 0, 11);
  for (var i = 0; i < recap.reports.length; i++) {
    final r = recap.reports[i];
    list.appendRow([
      IntCellValue(i + 1),
      TextCellValue(dateTimeLabel(r.createdAt)),
      TextCellValue(r.category),
      TextCellValue(r.location),
      TextCellValue(Regions.shortName(r.areaId)),
      TextCellValue(r.severity.label),
      TextCellValue(r.status.label),
      r.hasCoordinates ? DoubleCellValue(r.lat!) : TextCellValue('-'),
      r.hasCoordinates ? DoubleCellValue(r.lng!) : TextCellValue('-'),
      TextCellValue(r.authorName),
      TextCellValue(r.description),
    ]);
  }

  // Lembar bawaan "Sheet1" tidak dipakai.
  if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
  return excel.save() ?? <int>[];
}

/// Menulis berkas ke folder sementara lalu membuka lembar bagikan sistem
/// (simpan ke Drive, kirim lewat WhatsApp/email, dsb.).
class ExportService {
  ExportService._();

  static const String pdfMime = 'application/pdf';
  static const String xlsxMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static Future<void> share(
    List<int> bytes,
    String filename,
    String mime, {
    String? subject,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mime, name: filename)],
      subject: subject,
      text: subject,
    );
  }
}
