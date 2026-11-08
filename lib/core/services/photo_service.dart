import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../db/database.dart';

/// Fotograf secme, kucultme ve dosya islemleri (PLAN 10).
/// - Tam boyut: uzun kenar en fazla [maxSize] px, JPEG kalite [quality].
/// - Kucuk resim: kisa kenar [thumbSize] px (listelerde sadece bu yuklenir).
/// - Dosyalar `photos/` klasorunde; veritabaninda sadece dosya adlari.
class PhotoService {
  static const maxSize = 1600;
  static const thumbSize = 300;
  static const quality = 80;

  final _picker = ImagePicker();

  /// Kameradan bir, galeriden birden fazla fotograf. Vazgecilirse bos liste.
  Future<List<String>> pick({required bool camera}) async {
    // image_picker uzun kenari sinirlar ve EXIF yonunu korur; asil sikistirma [store]'da
    if (camera) {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxSize.toDouble(),
        maxHeight: maxSize.toDouble(),
        imageQuality: 95,
      );
      return [?file?.path];
    }
    final files = await _picker.pickMultiImage(
      maxWidth: maxSize.toDouble(),
      maxHeight: maxSize.toDouble(),
      imageQuality: 95,
    );
    return [for (final f in files) f.path];
  }

  /// Android kamera acikken uygulamayi kapatmissa, donen fotograflar.
  Future<List<String>> retrieveLost() async {
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return const [];
    return [for (final f in response.files ?? const <XFile>[]) f.path];
  }

  /// Fotografi JPEG'e cevirip (yonu duzeltilmis) photos/ klasorune yazar, kucuk resmini uretir.
  Future<({String fileName, String thumbFileName})> store(String sourcePath, String photosDir) async {
    await Directory(photosDir).create(recursive: true);
    final id = newId();
    final fileName = '$id.jpg';
    final thumbFileName = '${id}_k.jpg';
    final full = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      p.join(photosDir, fileName),
      // Zaten en fazla 1600 px; olcek 1 kalir, sadece yon ve kalite uygulanir
      minWidth: maxSize,
      minHeight: maxSize,
      quality: quality,
    );
    if (full == null) throw const FileSystemException('Fotoğraf kaydedilemedi');
    final thumb = await FlutterImageCompress.compressAndGetFile(
      full.path,
      p.join(photosDir, thumbFileName),
      minWidth: thumbSize,
      minHeight: thumbSize,
      quality: 75,
    );
    if (thumb == null) {
      await File(full.path).delete();
      throw const FileSystemException('Küçük resim oluşturulamadı');
    }
    return (fileName: fileName, thumbFileName: thumbFileName);
  }

  /// Fotografin iki dosyasini da siler (yoksa sessizce gecer).
  Future<void> deleteFiles(Photo photo, String photosDir) async {
    for (final name in [photo.fileName, photo.thumbFileName]) {
      final f = File(p.join(photosDir, name));
      if (await f.exists()) await f.delete();
    }
  }
}
