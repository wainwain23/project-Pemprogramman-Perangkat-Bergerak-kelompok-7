import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app_state.dart';
import '../config.dart';
import '../data/regions.dart';
import '../geo.dart';
import '../models.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'report_detail_screen.dart';

/// Peta kejadian interaktif (flutter_map + OpenStreetMap). Menampilkan
/// laporan, posko, SOS aktif (untuk pengawas), area siaran darurat, dan
/// posisi pengguna, semuanya dari koordinat GPS sungguhan.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _controller = MapController();
  bool _showReports = true;
  bool _showPosko = true;
  bool _showSos = true;
  bool _showBroadcast = true;
  bool _locating = false;

  late final LatLng _initialCenter;
  late final double _initialZoom;

  @override
  void initState() {
    super.initState();
    final s = AppState.instance;
    GeoPoint? p = s.loggedIn ? s.myReferencePoint : null;
    if (p == null && s.loggedIn) {
      for (final r in _visibleReports(s)) {
        if (r.hasCoordinates) {
          p = GeoPoint(r.lat!, r.lng!);
          break;
        }
      }
    }
    if (p != null) {
      _initialCenter = LatLng(p.lat, p.lng);
      _initialZoom = 15;
    } else {
      _initialCenter = const LatLng(-2.5, 118.0); // tengah Indonesia
      _initialZoom = 4.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Wilayah yang ditampilkan: kelurahan pengguna, atau wilayah kewenangan
  /// untuk Admin Wilayah dan Super Admin.
  String _area(AppState s) {
    if (s.isAdmin || s.isSuperAdmin) return s.myAuthorityArea;
    return Regions.ancestorAtLevel(s.me.areaId, RegionLevel.kelurahan) ??
        s.me.areaId;
  }

  List<Report> _visibleReports(AppState s) {
    final area = _area(s);
    return s.reports
        .where((r) =>
            r.status.isActive &&
            Regions.isWithin(r.areaId, area) &&
            r.hasCoordinates)
        .toList();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final res = await LocationService.current();
    if (!mounted) return;
    setState(() => _locating = false);
    if (res.ok) {
      AppState.instance.updateMyLocation(res.fix!.lat, res.fix!.lng);
      _controller.move(LatLng(res.fix!.lat, res.fix!.lng), 16);
    } else {
      snack(context, res.message);
    }
  }

  void _sheet(Widget child) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: child,
        ),
      ),
    );
  }

  void _reportSheet(Report r) {
    _sheet(Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 8, children: [
          StatusChip(label: r.severity.label, color: severityColor(r.severity)),
          StatusChip(label: r.status.label, color: statusColor(r.status)),
        ]),
        const SizedBox(height: 8),
        Text('${r.category} - ${r.location}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text('${Regions.shortName(r.areaId)} - ${timeAgo(r.createdAt)}',
            style: const TextStyle(color: kGray)),
        const SizedBox(height: 8),
        Text(r.description, maxLines: 4, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => ReportDetailScreen(reportId: r.id)),
              );
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Buka detail laporan'),
          ),
        ),
      ],
    ));
  }

  void _poskoSheet(EvacuationPoint p) {
    _sheet(Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusChip(label: 'Posko - ${p.state.label}', color: poskoColor(p.state)),
        const SizedBox(height: 8),
        Text(p.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(p.address, style: const TextStyle(color: kGray)),
        const SizedBox(height: 8),
        Text('${p.occupants} dari ${p.capacity} orang, sisa ${p.remaining}.'),
        if (p.lowStock.isNotEmpty)
          Text('Stok menipis: ${p.lowStock.map((i) => i.name).join(', ')}',
              style: const TextStyle(color: kRed)),
        if (p.phone != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => callPhone(context, p.phone!),
            icon: const Icon(Icons.call),
            label: Text('Telepon ${p.phone}'),
          ),
        ],
      ],
    ));
  }

  void _sosSheet(SosEvent e) {
    final owner = AppState.instance.userByEmail(e.ownerEmail);
    _sheet(Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StatusChip(label: 'SOS aktif', color: kRed),
        const SizedBox(height: 8),
        Text(e.ownerName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text('${Regions.shortName(e.areaId)} - ${dateTimeLabel(e.createdAt)}',
            style: const TextStyle(color: kGray)),
        const SizedBox(height: 4),
        Text(e.statusLabel),
        if (owner != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => callPhone(context, owner.phone),
            icon: const Icon(Icons.call),
            label: const Text('Hubungi'),
          ),
        ],
      ],
    ));
  }

  Marker _pin(GeoPoint p, IconData icon, Color color, VoidCallback onTap,
      {double size = 40}) {
    return Marker(
      point: LatLng(p.lat, p.lng),
      width: size + 8,
      height: size + 8,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: onTap,
        child: Icon(icon, size: size, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Peta Kejadian')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Lokasi saya',
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        onPressed: _locating ? null : _locate,
        child: _locating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.my_location),
      ),
      body: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final s = AppState.instance;
          if (!s.loggedIn) return const SizedBox.shrink();
          final area = _area(s);
          final reports = _visibleReports(s);
          final noCoord = s.reports
              .where((r) =>
                  r.status.isActive &&
                  Regions.isWithin(r.areaId, area) &&
                  !r.hasCoordinates)
              .length;
          final posko = s.evacuationPoints
              .where((p) =>
                  p.hasCoordinates &&
                  (Regions.isWithin(p.areaId, area) ||
                      Regions.isWithin(area, p.areaId)))
              .toList();
          final sos = s.canSeeSos
              ? s
                  .sosInMyArea()
                  .where((e) => e.hasCoordinates)
                  .toList()
              : <SosEvent>[];
          final me = s.currentUser!;

          // Area siaran darurat terbaru yang berpusat di titik tertentu.
          EmergencyBroadcast? bc;
          final since = DateTime.now().subtract(const Duration(hours: 24));
          for (final b in s.broadcasts) {
            if (b.hasCenter &&
                b.createdAt.isAfter(since) &&
                Regions.isWithin(area, b.areaId)) {
              bc = b;
              break;
            }
          }

          // Radius peringatan di sekitar laporan bahaya yang terverifikasi.
          final hot = reports
              .where((r) =>
                  r.severity == Severity.bahaya &&
                  r.status != ReportStatus.menunggu)
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text('Laporan'),
                      selected: _showReports,
                      onSelected: (v) => setState(() => _showReports = v),
                    ),
                    FilterChip(
                      label: const Text('Posko'),
                      selected: _showPosko,
                      onSelected: (v) => setState(() => _showPosko = v),
                    ),
                    if (s.canSeeSos)
                      FilterChip(
                        label: const Text('SOS'),
                        selected: _showSos,
                        onSelected: (v) => setState(() => _showSos = v),
                      ),
                    FilterChip(
                      label: const Text('Area siaran'),
                      selected: _showBroadcast,
                      onSelected: (v) => setState(() => _showBroadcast = v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${Regions.fullName(area)}'
                    '${noCoord > 0 ? '\n$noCoord laporan aktif tanpa koordinat tidak ditampilkan di peta.' : ''}',
                    style: const TextStyle(fontSize: 12, color: kGray),
                  ),
                ),
              ),
              Expanded(
                child: FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: _initialZoom,
                    minZoom: 3,
                    maxZoom: 19,
                    backgroundColor: const Color(0xFFE9EEE2),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    if (AppConfig.mapTilesEnabled)
                      TileLayer(
                        urlTemplate: AppConfig.mapTileUrl,
                        userAgentPackageName: AppConfig.packageName,
                      ),
                    CircleLayer(
                      circles: [
                        if (_showReports)
                          for (final r in hot)
                            CircleMarker(
                              point: LatLng(r.lat!, r.lng!),
                              radius: s.alertRadiusM,
                              useRadiusInMeter: true,
                              color: const Color(0x33E4572E),
                              borderColor: kRed,
                              borderStrokeWidth: 2,
                            ),
                        if (_showBroadcast && bc != null)
                          CircleMarker(
                            point: LatLng(bc.lat!, bc.lng!),
                            radius: bc.radiusM!,
                            useRadiusInMeter: true,
                            color: const Color(0x22B3261E),
                            borderColor: const Color(0xFFB3261E),
                            borderStrokeWidth: 2,
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        if (_showPosko)
                          for (final p in posko)
                            _pin(GeoPoint(p.lat!, p.lng!), Icons.home_work,
                                poskoColor(p.state), () => _poskoSheet(p)),
                        if (_showReports)
                          for (final r in reports)
                            _pin(GeoPoint(r.lat!, r.lng!), Icons.location_on,
                                severityColor(r.severity),
                                () => _reportSheet(r),
                                size: 44),
                        if (_showSos)
                          for (final e in sos)
                            _pin(GeoPoint(e.lat!, e.lng!), Icons.sos, kRed,
                                () => _sosSheet(e),
                                size: 40),
                        if (me.hasLocation)
                          Marker(
                            point: LatLng(me.lastLat!, me.lastLng!),
                            width: 22,
                            height: 22,
                            child: Container(
                              decoration: BoxDecoration(
                                color: kBlue,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (AppConfig.mapTilesEnabled)
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: Wrap(
                  spacing: 12,
                  children: [
                    _Legend(color: kRed, text: 'Bahaya'),
                    _Legend(color: kYellow, text: 'Waspada'),
                    _Legend(color: kBlue, text: 'Info / posisi Anda'),
                    _Legend(color: kTeal, text: 'Posko tersedia'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, size: 12, color: color),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 12)),
    ]);
  }
}
