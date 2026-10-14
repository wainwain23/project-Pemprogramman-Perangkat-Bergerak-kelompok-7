import 'dart:async';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'screens/super_admin_screens.dart';
import 'services/push_service.dart';
import 'theme.dart';
import 'widgets/alarm_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Siaran darurat dari FCM diteruskan ke state aplikasi (menjadi alarm).
  PushService.instance.onBroadcast = (b) {
    AppState.instance.receiveRemoteBroadcast(b);
  };

  runApp(const WargaSiagaApp());

  // Inisialisasi FCM tidak memblokir tampilan awal. Tanpa konfigurasi
  // Firebase, init() gagal dengan tenang dan aplikasi memakai penyampaian
  // dalam aplikasi saja. Setelah siap, berlangganan topik wilayah pengguna.
  unawaited(PushService.instance.init().then((_) async {
    final u = AppState.instance.currentUser;
    if (u != null) await PushService.instance.syncTopics(u.areaId);
  }));
}

class WargaSiagaApp extends StatelessWidget {
  const WargaSiagaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return MaterialApp(
          title: 'Warga Siaga',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          // Mode font besar untuk lansia, dan lapisan alarm siaran darurat
          // di atas semua halaman.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(state.largeFont ? 1.3 : 1.0),
              ),
              child: AlarmHost(child: child!),
            );
          },
          home: !state.loggedIn
              ? const AuthScreen()
              : (state.isSuperAdmin ? const SuperAdminShell() : const MainShell()),
        );
      },
    );
  }
}
