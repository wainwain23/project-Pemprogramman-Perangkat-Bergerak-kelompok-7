import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../data/regions.dart';
import '../models.dart';
import '../theme.dart';

/// Membungkus seluruh aplikasi. Saat ada siaran darurat yang belum diakui,
/// layar penuh peringatan ditampilkan di atas semua halaman, disertai nada
/// peringatan sistem dan getar berulang sampai pengguna menekan
/// "Saya mengerti".
///
/// Catatan: nada yang dipakai adalah nada peringatan bawaan sistem
/// (`SystemSound.alert`), bukan sirene khusus. Sirene khusus dan alarm yang
/// menembus mode senyap membutuhkan aset audio dan saluran notifikasi
/// Android prioritas tinggi (lihat docs/FCM_SETUP.md).
class AlarmHost extends StatefulWidget {
  final Widget child;
  const AlarmHost({super.key, required this.child});

  @override
  State<AlarmHost> createState() => _AlarmHostState();
}

class _AlarmHostState extends State<AlarmHost> {
  Timer? _timer;
  String? _shownId;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onState);
    _onState();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onState);
    _timer?.cancel();
    super.dispose();
  }

  void _onState() {
    final id = AppState.instance.pendingAlarm?.id;
    if (id == _shownId) return;
    _shownId = id;
    _timer?.cancel();
    _timer = null;
    if (id != null) {
      _ring();
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _ring());
    }
    if (mounted) setState(() {});
  }

  void _ring() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final alarm = AppState.instance.pendingAlarm;
    return Stack(
      children: [
        widget.child,
        if (alarm != null)
          Positioned.fill(
            child: _AlarmOverlay(
              broadcast: alarm,
              onAck: () => AppState.instance.acknowledgeAlarm(alarm.id),
            ),
          ),
      ],
    );
  }
}

class _AlarmOverlay extends StatelessWidget {
  final EmergencyBroadcast broadcast;
  final VoidCallback onAck;
  const _AlarmOverlay({required this.broadcast, required this.onAck});

  @override
  Widget build(BuildContext context) {
    final b = broadcast;
    final bg = switch (b.severity) {
      Severity.bahaya => const Color(0xFFB3261E),
      Severity.waspada => const Color(0xFFB26A00),
      Severity.info => const Color(0xFF1F4E8C),
    };
    return Semantics(
      liveRegion: true,
      label: 'Siaran darurat. ${b.title}. ${b.message}',
      child: Material(
        color: bg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Icon(Icons.warning_amber_rounded,
                    size: 88, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  'SIARAN DARURAT - ${b.severity.label.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          b.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          b.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 19, height: 1.35),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Wilayah: ${Regions.fullName(b.areaId)}'
                          '${b.hasCenter ? '\nRadius ${b.radiusM!.round()} m dari titik kejadian' : ''}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Dari ${b.senderName} (${b.senderRole}) - ${clock(b.createdAt)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onAck,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: kNavy,
                    minimumSize: const Size.fromHeight(56),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Saya mengerti'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
