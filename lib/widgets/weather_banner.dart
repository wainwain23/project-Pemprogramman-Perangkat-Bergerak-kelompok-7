import 'package:flutter/material.dart';
import '../models.dart';
import '../services/weather_service.dart';
import '../theme.dart';
import 'common.dart';

/// Banner peringatan dini cuaca ekstrem untuk kelurahan pengguna. Data dari
/// BMKG (atau data contoh yang ditandai jelas bila API dimatikan). Atribusi
/// BMKG selalu ditampilkan bila data BMKG dipakai.
class WeatherBanner extends StatefulWidget {
  final String areaId;
  const WeatherBanner({super.key, required this.areaId});

  @override
  State<WeatherBanner> createState() => _WeatherBannerState();
}

class _WeatherBannerState extends State<WeatherBanner> {
  late Future<WeatherReport> _future = WeatherService.load(widget.areaId);

  @override
  void didUpdateWidget(WeatherBanner old) {
    super.didUpdateWidget(old);
    if (old.areaId != widget.areaId) {
      _future = WeatherService.load(widget.areaId);
    }
  }

  void _reload() {
    setState(() => _future = WeatherService.load(widget.areaId, force: true));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherReport>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        final report = snap.data;
        if (report == null) return const SizedBox.shrink();
        final sample = report.alerts.any((a) => a.sample);
        final children = <Widget>[];
        for (final a in report.alerts.take(3)) {
          children.add(_alertCard(context, a));
        }
        if (report.error != null) {
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.cloud_off, size: 16, color: kGray),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(report.error!,
                      style: const TextStyle(fontSize: 12, color: kGray)),
                ),
                TextButton(onPressed: _reload, child: const Text('Muat ulang')),
              ],
            ),
          ));
        }
        if (children.isEmpty) return const SizedBox.shrink();
        if (!sample && report.alerts.isNotEmpty) {
          children.add(const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(kBmkgAttribution,
                style: TextStyle(fontSize: 11, color: kGray)),
          ));
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
      },
    );
  }

  Widget _alertCard(BuildContext context, WeatherAlert a) {
    final color = severityColor(a.severity);
    return Card(
      color: a.severity == Severity.bahaya
          ? const Color(0xFFFAD6CD)
          : const Color(0xFFFFF3D6),
      child: ListTile(
        leading: Icon(Icons.thunderstorm, color: color, size: 32),
        title: Text(a.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${a.detail}\n${a.sample ? 'DATA CONTOH' : a.source}'
          '${a.issuedAt == null ? '' : ' - ${timeAgo(a.issuedAt!)}'}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        onTap: () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(a.title),
            content: SingleChildScrollView(
              child: Text(
                  '${a.detail}\n\n${a.sample ? 'Ini data contoh, bukan data resmi.' : '${a.source}\n$kBmkgAttribution'}'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup')),
            ],
          ),
        ),
      ),
    );
  }
}
