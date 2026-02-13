import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageCompressor {
  static const int maxBytes = 100 * 1024; // 100KB

  /// Compresses an image file to be under [maxBytes].
  /// Returns the compressed bytes.
  static Future<Uint8List?> compressFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) return null;

      // 1. Resize if too large (e.g. > 800px width)
      if (image.width > 800) {
        image = img.copyResize(image, width: 800);
      }

      int quality = 85;
      List<int> compressed = img.encodeJpg(image, quality: quality);

      // 2. Reduce quality until size < maxBytes
      while (compressed.length > maxBytes && quality > 10) {
        quality -= 10;
        compressed = img.encodeJpg(image, quality: quality);
      }

      return Uint8List.fromList(compressed);
    } catch (e) {
      print('Image Compression Error: $e');
      return null;
    }
  }
}
