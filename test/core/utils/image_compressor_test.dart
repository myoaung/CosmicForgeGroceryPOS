import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/utils/image_compressor.dart';
import 'package:image/image.dart' as img;

void main() {
  test('compressFile reduces image size to under 100KB', () async {
    // 1. Create a large dummy image (e.g. 2000x2000 noise)
    final largeImage = img.Image(width: 2000, height: 2000);
    // Fill with noise to make it incompressible? 
    // Actually simple noise is fine, or just a large flat color might compress too well.
    // Let's draw some random pixels.
    for (var y = 0; y < 2000; y++) {
      for (var x = 0; x < 2000; x++) {
        largeImage.setPixel(x, y, img.ColorFloat16.rgb(x % 255, y % 255, (x+y) % 255));
      }
    }
    
    // Encode to JPG first to get a "File" representation
    final originalBytes = img.encodeJpg(largeImage, quality: 100);
    final tempDir = Directory.systemTemp.createTempSync();
    final file = File('${tempDir.path}/test_image.jpg');
    await file.writeAsBytes(originalBytes);
    
    final originalSize = await file.length();
    print('Original Size: ${originalSize / 1024} KB');
    
    // 2. Compress
    final compressedBytes = await ImageCompressor.compressFile(file);
    
    expect(compressedBytes, isNotNull);
    final compressedSize = compressedBytes!.length;
    print('Compressed Size: ${compressedSize / 1024} KB');
    
    // 3. Verify
    expect(compressedSize, lessThanOrEqualTo(100 * 1024)); // < 100KB
    
    // Cleanup
    await tempDir.delete(recursive: true);
  });
}
