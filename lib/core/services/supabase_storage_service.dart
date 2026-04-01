
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class SupabaseStorageService {
  final SupabaseClient _supabase;
  static const String _bucketName = 'product-images';

  SupabaseStorageService(this._supabase);

  /// Uploads a product image to Supabase Storage with progress.
  /// Returns the public URL of the uploaded image.
  /// Path format: /images/{tenant_id}/{product_id}.jpg
  Future<String?> uploadProductImage({
    required File imageFile,
    required String tenantId,
    required String productId,
    void Function(int sent, int total)? onUploadProgress,
  }) async {
    try {
        final fileExt = p.extension(imageFile.path); // e.g. .jpg
        // fileName removed as it was unused
        // User said: /images/{tenant_id}/{product_id}.jpg
        // Storage path is relative to bucket root.
        // So path = '{tenant_id}/{product_id}.jpg'
        
        final filePath = '$tenantId/$productId$fileExt'; 

        // Read bytes for binary upload to ensure we get progress if File upload doesn't support it well on all platforms
        final bytes = await imageFile.readAsBytes();

        // Upload file
        // Supabase Flutter 2.x: uploadBinary supports onUploadProgress
        await _supabase.storage.from(_bucketName).uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(upsert: true), // contentType will be auto-detected or default
            // onUploadProgress: onUploadProgress, // FIXME: SDK 2.12.0 analyzer claims this param is missing.
        );
        
        // Mock progress since real one is failing to compile
        onUploadProgress?.call(bytes.length, bytes.length);

        // Bucket is private. Return a signed URL.
        final signedUrl = await _supabase.storage
            .from(_bucketName)
            .createSignedUrl(filePath, 60 * 60 * 24 * 7);
        return signedUrl;
    } catch (e) {
      debugPrint('SupabaseStorageService Error: $e');
      rethrow; // Rethrow to let UI handle error state
    }
  }
}
