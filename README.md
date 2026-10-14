# Warga Siaga

Warga Siaga merupakan aplikasi mobile berbasis Flutter yang dirancang untuk mendukung pelaporan warga, peringatan dini, dan koordinasi tanggap darurat berbasis lokasi pada tingkat wilayah. Aplikasi menggunakan konsep hierarki wilayah (Provinsi, Kota/Kabupaten, Kecamatan, Kelurahan/Desa, RW, dan RT) sehingga informasi seperti laporan kejadian, pengumuman, dan titik evakuasi dapat dikelola sesuai cakupan wilayah pengguna. Aplikasi ini dikembangkan sebagai prototype dalam tugas akhir mata kuliah Pemrograman Perangkat Bergerak.

## Anggota Kelompok

| Nama | NIM |
|---|---|
| Nayla Octamandhani | [NIM] |
| Sopi Amelia Salsabila | [NIM] |
| Leyla Hasni AD | [NIM] |
| [Nama 4] | [NIM] |

## Peran dan hak akses

| Peran | Daftar sendiri | Persetujuan | Kewenangan utama |
|---|---|---|---|
| Warga | ya | otomatis aktif | lapor, SOS, status keselamatan keluarga, konfirmasi laporan, lihat peta/posko/kontak |
| Ketua RT | ya | Admin Wilayah | verifikasi/tolak laporan di RT-nya, setujui relawan RT, pengumuman, posko |
| Petugas Lapangan | ya | Admin Wilayah | ambil/tangani laporan, tugas, laporan lapangan, siaran darurat, tanggapi SOS, ekspor |
| Relawan | ya | Admin Wilayah atau Ketua RT | tanggapi SOS, papan bantuan, posko dan logistik, tugas |
| Admin Wilayah | tidak (dibuat Super Admin) | - | seluruh kelurahan/kecamatan/kota yang ditetapkan: verifikasi, penugasan, persetujuan akun, RW/RT, siaran, statistik, ekspor |
| Super Admin | tidak | - | kelola semua akun, peran, dan wilayah kewenangan; wilayah mana pun |

Akun yang belum disetujui dapat masuk, tetapi hanya melihat banner "menunggu persetujuan" dan tidak
mendapat hak peran. Penolakan wajib beralasan dan diberitahukan ke pendaftar.
Wilayah kewenangan (regional scoping) diubah Super Admin dari layar Akun tanpa mengubah kode.

## Konsep multi-wilayah

Wilayah berbentuk pohon: **Provinsi > Kota/Kab. > Kecamatan > Kelurahan/Desa > RW > RT**.
Id provinsi sampai kelurahan memakai kode Kemendagri (contoh `32.73.07.1004`).
Data nasional berhenti di kelurahan/desa; **RW dan RT dikelola lokal di aplikasi** (Admin Wilayah
atau Super Admin menambahkannya, dan warga bisa menambah saat mendaftar). Daftar wilayah dimuat dari
API wilayah.id bila tersedia, dan jatuh ke data contoh (Bandung, Jakarta Selatan, Surabaya, Medan)
bila jaringan gagal; pemilih wilayah menampilkan pemberitahuan saat itu terjadi.

## Fitur

**Autentikasi dan akun** - daftar dengan pemilih wilayah bertingkat, masuk/keluar, lupa sandi (kode
simulasi), penguncian login, persetujuan akun, manajemen akun Super Admin (cari, filter peran/status,
buat, ubah peran dan wilayah).

**SOS dan darurat** - tombol SOS tahan 3 detik dengan koordinat GPS, tombol telepon 112, batal
beralasan, riwayat, pemantau SOS untuk pengawas (tanggapi, hubungi, salin koordinat), siaran darurat
(per wilayah atau radius dari titik GPS, pratinjau jumlah penerima, riwayat dan jumlah yang
mengonfirmasi), alarm layar penuh sampai "Saya mengerti", penerima push FCM berbasis topik wilayah,
banner peringatan cuaca BMKG.

**Laporan** - GPS otomatis, foto dari kamera, deteksi laporan ganda menurut jarak (150 m) dan waktu
(6 jam), status Menunggu, Terverifikasi, Diproses, Selesai, Ditolak, linimasa audit tiap perubahan,
penugasan ke petugas, laporan lapangan, komentar, konfirmasi warga, antrean offline.

**Keselamatan dan logistik** - status keselamatan keluarga (Aman, Butuh bantuan, Belum diketahui,
"Kami semua aman"), rekap rumah tangga untuk pengurus, orang hilang (foto opsional, tandai
ditemukan), posko dengan kapasitas/hunian/stok logistik dan urut terdekat, tugas dan papan bantuan,
kontak darurat nasional/lokal/pribadi dengan satu ketukan telepon.

**Peta, statistik, ekspor** - peta OpenStreetMap (`flutter_map`) dengan laporan, posko, SOS, posisi
sendiri, lingkaran radius peringatan dan siaran; rekap per kategori dan tingkat bahaya, tren 7/30
hari; ekspor PDF dan Excel (hanya untuk peran berwenang) lewat lembar bagikan sistem.

## Akun demo (sandi `123456`)

| Email | Peran |
|---|---|
| warga@demo.id | Warga, RT 03/RW 05 Kel. Sukagalih |
| rt@demo.id | Ketua RT 03 |
| petugas@demo.id | Petugas Lapangan |
| relawan@demo.id | Relawan |
| admin@demo.id | Admin Wilayah Kel. Sukagalih |
| super@demo.id | Super Admin |
| sari@demo.id, joni@demo.id, tono@demo.id | menunggu persetujuan |

## Status jujur: apa yang nyata dan apa yang belum

`flutter analyze` dan `flutter test` **belum pernah dijalankan** pada kode ini (lingkungan penyusun
tidak memiliki Flutter SDK). Jalankan keduanya lebih dulu dan perbaiki bila ada galat kompilasi.

| Hal | Status |
|---|---|
| Penyimpanan data | Semua data aplikasi (akun, laporan, posko, dst.) ada di memori dan hilang saat aplikasi ditutup. Belum ada server atau database |
| Kata sandi | Teks biasa di memori, hanya untuk demo. Server nyata wajib memakai hash dan token |
| Data wilayah | API wilayah.id (butuh internet), fallback data contoh; RW/RT lokal |
| Cuaca | Peringatan dini dan prakiraan BMKG bila jaringan tersedia; bila gagal ditandai "DATA CONTOH" |
| Peta | Ubin OpenStreetMap publik (kebijakan penggunaan OSM berlaku; untuk produksi pakai penyedia ubin sendiri). Tanpa jaringan, ubin kosong |
| Siaran darurat | Sampai ke akun di aplikasi ini. Ke ponsel lain hanya lewat FCM, butuh proyek Firebase dan server pengirim (`docs/FCM_SETUP.md`) |
| Bunyi alarm | Nada peringatan bawaan sistem dan getar berulang, **bukan sirene khusus**; tidak menembus mode senyap |
| SMS ke kontak darurat | Tidak dikirim; butuh gateway SMS di server |
| Panggilan telepon | Membuka aplikasi telepon (`tel:`); tidak menelepon otomatis |
| Nomor kontak lokal dan posko | Nomor contoh; ganti dengan data resmi sebelum dipakai |
| Mode offline | Simulasi antrean; belum ada penyimpanan lokal nyata, peta offline, atau Bluetooth/Wi-Fi Direct |
| Foto laporan | Disimpan sebagai jalur berkas lokal; belum diunggah ke server |

## Cara menjalankan

Butuh Flutter 3.27 atau lebih baru (Dart 3.6).

```bash
cd warga_siaga
flutter create --platforms=android,ios --org com.kelompok --project-name warga_siaga .
python3 tool/setup_platform.py     # izin lokasi, kamera, notifikasi, telepon
flutter pub get
flutter analyze
flutter test
flutter run
```

Saklar saat pengembangan (`--dart-define`): `REGION_API=false`, `WEATHER_API=false`,
`MAP_TILES=false`, `PUSH=false`.

Untuk notifikasi push lihat `docs/FCM_SETUP.md`.

## Struktur

```
lib/
  models.dart, safety_models.dart   model data
  app_state*.dart                   state dan aturan (akun, laporan, SOS/siaran, keselamatan/posko)
  config.dart, geo.dart, recap.dart  konfigurasi, jarak, rekap statistik
  data/                             wilayah (Kemendagri + RW/RT lokal), data contoh
  services/                         lokasi, kamera, telepon, push, wilayah, cuaca, ekspor
  screens/                          layar aplikasi
  widgets/                          SOS, alarm, pemilih wilayah, banner cuaca
test/                               tes wilayah, hak akses, siaran, SOS, tampilan
tool/setup_platform.py              menambah izin Android/iOS
docs/FCM_SETUP.md                   panduan push
```
