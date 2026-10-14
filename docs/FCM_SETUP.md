# Menyiapkan notifikasi push (FCM)

Aplikasi sudah memuat kode penerima FCM (`lib/services/push_service.dart`), tetapi **tidak membawa
proyek Firebase**. Tanpa langkah di bawah, siaran darurat tetap sampai ke akun yang ada di dalam
aplikasi yang sama (simulasi dalam aplikasi), dan layar Siaran Darurat menampilkan peringatan bahwa
pengiriman push belum aktif. Pengiriman ke ponsel lain membutuhkan proyek Firebase milik Anda dan
sebuah server (atau Cloud Function) yang mengirim pesan.

## 1. Hubungkan aplikasi ke Firebase

1. Buat proyek di <https://console.firebase.google.com>.
2. Tambahkan aplikasi Android dengan package `com.kelompok.warga_siaga` (sama dengan `--org` + nama
   proyek saat `flutter create`) dan unduh `google-services.json` ke `android/app/`.
3. Tambahkan aplikasi iOS, unduh `GoogleService-Info.plist` ke `ios/Runner/`, lalu unggah kunci APNs
   di Firebase Console (Project settings, Cloud Messaging).
4. Cara tercepat memasang plugin Gradle/Xcode: `dart pub global activate flutterfire_cli` lalu
   `flutterfire configure`. Setelah itu `Firebase.initializeApp()` pada `PushService.init` berfungsi.
5. Izin `POST_NOTIFICATIONS` dan `VIBRATE` ditambahkan oleh `python3 tool/setup_platform.py`.

Untuk mematikan push saat pengembangan: `flutter run --dart-define=PUSH=false`.

## 2. Topik per wilayah

Setelah masuk, aplikasi berlangganan topik untuk wilayah akun dan seluruh induknya (RT, RW,
kelurahan, kecamatan, kota, provinsi), dengan nama `region_<id wilayah>`. Contoh untuk RT 03/RW 05
Kel. Sukagalih: `region_32`, `region_32.73`, `region_32.73.07`, `region_32.73.07.1004`,
`region_rw-sg-05`, `region_rt-sg-05-03`. Mengirim ke topik kelurahan menjangkau semua akun di
kelurahan itu.

Catatan: id RW/RT bersifat lokal aplikasi (data resmi nasional berhenti di kelurahan/desa). Bila Anda
memakai server sendiri, server harus memakai id yang sama.

## 3. Kontrak payload

Semua nilai `data` FCM harus berupa string.

| Kunci | Wajib | Isi |
|---|---|---|
| `type` | ya | selalu `emergency_broadcast` |
| `id` | disarankan | id unik siaran (mencegah alarm ganda) |
| `title`, `message` | ya | judul (maks 80 karakter) dan isi |
| `severity` | tidak | `info`, `waspada`, atau `bahaya` (bawaan `bahaya`) |
| `areaId` | tidak | wilayah tujuan; akun di luar wilayah ini mengabaikan pesan |
| `lat`, `lng`, `radiusM` | tidak | bila ada, akun yang lokasi terakhirnya diketahui dan berada di luar radius mengabaikan pesan |
| `sender` | tidak | nama pengirim |

## 4. Contoh pengiriman (HTTP v1)

Butuh token OAuth2 akun layanan (`gcloud auth print-access-token` atau pustaka Admin SDK) dan
`PROJECT_ID` Firebase.

```bash
curl -X POST "https://fcm.googleapis.com/v1/projects/PROJECT_ID/messages:send" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "topic": "region_32.73.07.1004",
      "notification": {
        "title": "SIARAN DARURAT: Banjir bandang",
        "body": "Segera menuju titik evakuasi terdekat."
      },
      "data": {
        "type": "emergency_broadcast",
        "id": "bc-20261014-001",
        "title": "Banjir bandang",
        "message": "Segera menuju titik evakuasi terdekat.",
        "severity": "bahaya",
        "areaId": "32.73.07.1004",
        "sender": "Admin Kelurahan"
      },
      "android": { "priority": "HIGH" },
      "apns": { "headers": { "apns-priority": "10" } }
    }
  }'
```

## 5. Batasan yang perlu diketahui

- **Bunyi alarm.** Saat aplikasi terbuka, alarm layar penuh membunyikan nada peringatan bawaan
  sistem dan getar berulang sampai pengguna menekan "Saya mengerti". Itu bukan sirene khusus. Saat
  aplikasi tertutup, bunyi ditentukan oleh sistem untuk notifikasi (mengikuti mode senyap/Jangan
  Ganggu ponsel). Sirene khusus yang menembus mode senyap butuh kanal notifikasi Android berprioritas
  tinggi dengan berkas suara sendiri, atau entitlement "Critical Alerts" dari Apple. Keduanya belum
  ada di proyek ini.
- **Tidak ada jaminan sampai.** FCM adalah layanan upaya terbaik; ponsel mati, tanpa sinyal, atau
  menghemat baterai agresif dapat terlambat menerima. Jangan jadikan satu-satunya jalur peringatan.
- **SMS ke kontak darurat** tidak dikirim aplikasi ini. Itu membutuhkan gateway SMS di server.
- Pengiriman dari aplikasi ke perangkat lain tidak dilakukan langsung dari klien (kunci akun layanan
  tidak boleh ada di aplikasi). Server Anda yang mengirim.
