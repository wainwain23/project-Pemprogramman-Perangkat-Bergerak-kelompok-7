import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config.dart';
import '../data/regions.dart';
import '../models.dart';

/// Isi siaran darurat yang diterima lewat FCM. Kontrak payload `data`:
///
/// ```json
/// {
///   "type": "emergency_broadcast",
///   "id": "bc-123",
///   "title": "Banjir bandang",
///   "message": "Segera menuju titik evakuasi",
///   "severity": "bahaya",
///   "areaId": "32.73.07.1004",
///   "lat": "-6.8872", "lng": "107.5925", "radiusM": "1500",
///   "sender": "Admin Kelurahan"
/// }
/// ```
/// Semua nilai `data` FCM berupa string. Server mengirim ke topik
/// `region_<id wilayah>` (lihat [PushService.topicFor]).
class PushBroadcast {
  final String id;
  final String title;
  final String message;
  final Severity severity;
  final String? areaId;
  final double? lat;
  final double? lng;
  final double? radiusM;
  final String sender;
  const PushBroadcast({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    this.areaId,
    this.lat,
    this.lng,
    this.radiusM,
    this.sender = 'Pusat',
  });

  /// Membaca payload FCM; null bila bukan siaran darurat.
  static PushBroadcast? fromData(
    Map<String, dynamic> data, {
    String? fallbackTitle,
    String? fallbackBody,
    String? messageId,
  }) {
    final type = data['type']?.toString();
    if (type != 'emergency_broadcast') return null;
    final title = (data['title'] ?? fallbackTitle ?? 'Peringatan darurat')
        .toString();
    final message = (data['message'] ?? fallbackBody ?? '').toString();
    final sev = switch (data['severity']?.toString()) {
      'info' => Severity.info,
      'waspada' => Severity.waspada,
      _ => Severity.bahaya,
    };
    double? dbl(String key) => double.tryParse(data[key]?.toString() ?? '');
    return PushBroadcast(
      id: (data['id'] ?? messageId ?? 'push-${DateTime.now().millisecondsSinceEpoch}')
          .toString(),
      title: title,
      message: message,
      severity: sev,
      areaId: data['areaId']?.toString(),
      lat: dbl('lat'),
      lng: dbl('lng'),
      radiusM: dbl('radiusM'),
      sender: (data['sender'] ?? 'Pusat').toString(),
    );
  }
}

/// Handler pesan saat aplikasi di latar belakang/tertutup. Harus fungsi
/// tingkat atas. Notifikasi sistem ditampilkan sendiri oleh FCM.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Tanpa konfigurasi Firebase tidak ada yang bisa dilakukan.
  }
}

/// Notifikasi push (FCM). Bila proyek Firebase belum dikonfigurasi
/// (`google-services.json` / `GoogleService-Info.plist` tidak ada), [init]
/// gagal dengan tenang dan aplikasi memakai penyampaian dalam aplikasi.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool ready = false;
  String? token;
  String? lastError;

  /// Dipasang oleh aplikasi: dipanggil saat siaran darurat masuk.
  void Function(PushBroadcast broadcast)? onBroadcast;

  final Set<String> _topics = <String>{};

  static String topicFor(String regionId) {
    final safe = regionId.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.~%]'), '_');
    return 'region_$safe';
  }

  Future<void> init() async {
    if (!AppConfig.pushEnabled || ready) return;
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 8));
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      token = await messaging.getToken();
      messaging.onTokenRefresh.listen((t) => token = t);
      FirebaseMessaging.onMessage.listen(_handle);
      FirebaseMessaging.onMessageOpenedApp.listen(_handle);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handle(initial);
      ready = true;
      lastError = null;
    } catch (e) {
      ready = false;
      lastError = e.toString();
    }
  }

  void _handle(RemoteMessage message) {
    final b = PushBroadcast.fromData(
      Map<String, dynamic>.from(message.data),
      fallbackTitle: message.notification?.title,
      fallbackBody: message.notification?.body,
      messageId: message.messageId,
    );
    if (b != null) onBroadcast?.call(b);
  }

  /// Berlangganan topik untuk wilayah pengguna dan seluruh induknya (kota,
  /// kecamatan, kelurahan, RW, RT), lalu berhenti dari topik yang tak
  /// diperlukan. [areaId] null berarti keluar dari semua topik.
  Future<void> syncTopics(String? areaId) async {
    if (!ready) return;
    final wanted = <String>{
      if (areaId != null)
        for (final r in Regions.chain(areaId)) topicFor(r.id),
    };
    try {
      final messaging = FirebaseMessaging.instance;
      for (final t in wanted.difference(_topics)) {
        await messaging.subscribeToTopic(t);
      }
      for (final t in _topics.difference(wanted)) {
        await messaging.unsubscribeFromTopic(t);
      }
      _topics
        ..clear()
        ..addAll(wanted);
    } catch (e) {
      lastError = e.toString();
    }
  }
}
