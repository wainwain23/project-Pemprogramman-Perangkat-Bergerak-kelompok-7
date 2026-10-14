import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class PhotoResult {
  /// Lokasi berkas foto, atau null bila dibatalkan/gagal.
  final String? path;

  /// Pesan untuk pengguna bila gagal (null bila berhasil atau dibatalkan).
  final String? error;
  const PhotoResult({this.path, this.error});

  bool get ok => path != null;
  bool get cancelled => path == null && error == null;
}

/// Sumber foto. Diganti pada tes agar tidak membuka kamera.
abstract class PhotoProvider {
  Future<PhotoResult> capture();
}

/// Foto langsung dari kamera sistem (tanpa galeri, agar bukti foto asli).
class CameraPhotoProvider implements PhotoProvider {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<PhotoResult> capture() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (file == null) return const PhotoResult();
      return PhotoResult(path: file.path);
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      if (code.contains('denied') || code.contains('access')) {
        return const PhotoResult(
          error:
              'Izin kamera ditolak. Izinkan kamera di pengaturan aplikasi lalu coba lagi.',
        );
      }
      return const PhotoResult(error: 'Kamera tidak dapat dibuka.');
    } catch (_) {
      return const PhotoResult(error: 'Kamera tidak dapat dibuka.');
    }
  }
}

class CameraService {
  CameraService._();

  static PhotoProvider provider = CameraPhotoProvider();

  static Future<PhotoResult> capture() => provider.capture();
}
