import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warga_siaga/app_state.dart';
import 'package:warga_siaga/config.dart';
import 'package:warga_siaga/models.dart';
import 'package:warga_siaga/main.dart';
import 'package:warga_siaga/services/location_service.dart';

/// GPS palsu agar tes tidak memakai perangkat keras.
class _FakeLocation implements LocationProvider {
  @override
  Future<LocationResult> current() async => LocationResult.ok(
      LocationFix(-6.8868, 107.5919, 10, DateTime(2026, 1, 1)));

  @override
  Future<void> openSettings(LocationFailure failure) async {}
}

void main() {
  final savedProvider = LocationService.provider;

  setUp(() {
    // Tanpa jaringan: peta tanpa ubin, wilayah/cuaca memakai data bawaan.
    AppConfig.mapTilesEnabled = false;
    AppConfig.regionApiEnabled = false;
    AppConfig.weatherApiEnabled = false;
    AppConfig.pushEnabled = false;
    LocationService.provider = _FakeLocation();
    AppState.instance.resetForTests();
  });

  tearDown(() {
    LocationService.provider = savedProvider;
    AppState.instance.resetForTests();
  });

  testWidgets('Layar masuk tampil', (WidgetTester tester) async {
    await tester.pumpWidget(const WargaSiagaApp());
    expect(find.text('Warga Siaga'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Masuk'), findsOneWidget);
    expect(find.text('Lupa kata sandi?'), findsOneWidget);
  });

  // Pengujian pada berbagai ukuran layar dan ukuran font: tidak boleh ada
  // overflow atau exception saat berpindah antartab.
  const sizes = <Size>[
    Size(320, 568), // ponsel kecil
    Size(360, 640),
    Size(412, 915), // ponsel besar
    Size(768, 1024), // tablet
  ];
  const tabs = ['Beranda', 'Laporan', 'Peta', 'Info', 'Akun'];

  for (final size in sizes) {
    for (final large in [false, true]) {
      final name = '${size.width.toInt()}x${size.height.toInt()}, '
          'font ${large ? 'besar' : 'normal'}';
      testWidgets('Semua tab tampil tanpa error ($name)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final s = AppState.instance;
        expect(s.login('rt@demo.id', '123456'), isNull);
        s.setLargeFont(large);
        addTearDown(() {
          s.setLargeFont(false);
          s.logout();
        });

        await tester.pumpWidget(const WargaSiagaApp());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (final label in tabs) {
          await tester.tap(find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Tab $label');
        }
      });
    }
  }

  testWidgets('Super Admin melihat dasbor dan menu kelola akun', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = AppState.instance;
    expect(s.login('super@demo.id', '123456'), isNull);

    await tester.pumpWidget(const WargaSiagaApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (final label in ['Ringkasan', 'Akun', 'Wilayah', 'Pengaturan']) {
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Tab $label');
    }
  });

  testWidgets('Siaran darurat menampilkan alarm layar penuh sampai dikonfirmasi',
      (tester) async {
    final s = AppState.instance;
    expect(s.login('admin@demo.id', '123456'), isNull);
    final res = s.sendBroadcast(
      title: 'Banjir bandang',
      message: 'Segera menuju posko evakuasi.',
      severity: Severity.bahaya,
    );
    expect(res.success, isTrue);
    s.logout();
    expect(s.login('warga@demo.id', '123456'), isNull);

    await tester.pumpWidget(const WargaSiagaApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Banjir bandang'), findsWidgets);
    expect(find.text('Saya mengerti'), findsOneWidget);

    await tester.tap(find.text('Saya mengerti'));
    await tester.pumpAndSettle();
    expect(find.text('Saya mengerti'), findsNothing);
    expect(s.pendingAlarm, isNull);
  });
}
