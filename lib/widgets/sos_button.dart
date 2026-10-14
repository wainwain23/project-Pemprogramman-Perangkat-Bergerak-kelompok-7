import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// Tombol SOS: tahan 3 detik untuk mengirim (mencegah salah tekan).
class SosButton extends StatefulWidget {
  final VoidCallback onTriggered;
  final bool active;
  const SosButton({super.key, required this.onTriggered, this.active = false});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          widget.onTriggered();
          _c.reset();
        }
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.active
        ? 'SOS aktif'
        : (_c.isAnimating ? 'Tahan...' : 'Tahan 3 detik');
    return Listener(
      onPointerDown: (_) {
        if (!widget.active) _c.forward();
      },
      onPointerUp: (_) => _c.reset(),
      onPointerCancel: (_) => _c.reset(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Semantics(
            button: true,
            label: widget.active
                ? 'Tombol darurat SOS. SOS sedang aktif.'
                : 'Tombol darurat SOS. Tahan tiga detik untuk mengirim.',
            // Pengguna pembaca layar tidak bisa menahan 3 detik; beri jalur
            // alternatif lewat aksi tekan-lama aksesibilitas.
            onLongPress: widget.active
                ? null
                : () {
                    HapticFeedback.heavyImpact();
                    widget.onTriggered();
                  },
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFAD6CD),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: _c.value,
                      strokeWidth: 8,
                      color: kNavy,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.active ? kGray : kRed,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55E4572E),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'SOS',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(label, style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
