
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/features/products/providers/product_provider.dart';
import 'package:grocery/core/services/supabase_storage_service.dart';
import 'package:grocery/core/services/store_service.dart'; // For audit
import 'package:grocery/core/providers/store_provider.dart';
import 'package:grocery/core/providers/database_provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:grocery/features/products/widgets/shopify_upload_progress.dart';
import 'package:grocery/core/providers/sync_provider.dart';

// Provider for Storage Service
final storageServiceProvider = Provider((ref) => SupabaseStorageService(Supabase.instance.client));

class ProductEditScreen extends ConsumerStatefulWidget {
  final Product? product;

  const ProductEditScreen({super.key, this.product});

  @override
  ConsumerState<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends ConsumerState<ProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late String _unitType;
  bool _isTaxExempt = false;
  File? _imageFile;
  String? _existingImagePath;
  String? _existingImageUrl;
  bool _isUploading = false;
  bool _isUploadError = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(text: widget.product?.price.toString() ?? '');
    _unitType = widget.product?.unitType ?? 'UNIT';
    _isTaxExempt = widget.product?.isTaxExempt ?? false;
    _existingImagePath = widget.product?.imagePath;
    _existingImageUrl = widget.product?.imageUrl;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        // Reset URL if new local file picked, until uploaded
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    
    // Determine ID
    final productId = widget.product?.id ?? const Uuid().v4();

    // 1. Upload Image if new one selected OR retrying
    String? imageUrl = _existingImageUrl; // Keep old if not changed
    String? imagePath = _existingImagePath;

    if (_imageFile != null || (_existingImagePath != null && _existingImageUrl == null)) {
      File fileToUpload = _imageFile ?? File(_existingImagePath!);
      
      // Update local tracking
      imagePath = fileToUpload.path; 

      setState(() {
        _isUploading = true;
        _isUploadError = false;
        _uploadProgress = 0.0;
      });

      try {
        final tenantId = 'tenant_1'; // Mock or get from User/Auth
        // In real app, get tenantId from Auth Provider

        // In real app, get tenantId from Auth Provider
        
        final storage = ref.read(storageServiceProvider);
        
        final url = await storage.uploadProductImage(
          imageFile: fileToUpload,
          tenantId: tenantId, 
          productId: productId,
          onUploadProgress: (sent, total) {
             if (mounted) {
               setState(() {
                 _uploadProgress = sent / total;
               });
             }
          },
        );

        if (url != null) {
          imageUrl = url;
          // Update in memory so UI reflects it immediately if we don't close screen
          _existingImageUrl = url; 
          
          setState(() => _uploadProgress = 1.0);
          
          // Log Audit
          ref.read(storeServiceProvider).logAudit(
            actionType: 'IMAGE_UPLOAD',
            description: 'Uploaded image for product $name ($productId)'
          );
        } else {
             // Handle upload fail - retry UI logic could be here
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image upload failed. Saved locally. Text retry later.')));
        }

      } catch (e) {
        print('Upload Error: $e');
        if (mounted) {
          setState(() {
            _isUploadError = true;
            _isUploading = false; // Stop loading state so retry button shows
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload Error: $e')));
        }
      } finally {
        if (mounted && !_isUploadError) {
           setState(() => _isUploading = false);
        }
      }
    }

    // 2. Save to Drift
    final companion = ProductsCompanion(
      id: drift.Value(productId),
      name: drift.Value(name),
      price: drift.Value(price),
      unitType: drift.Value(_unitType),
      isTaxExempt: drift.Value(_isTaxExempt),
      imagePath: drift.Value(imagePath),
      imageUrl: drift.Value(imageUrl),
    );

    final controller = ref.read(productControllerProvider);
    
    if (widget.product == null) {
      await controller.addProduct(companion);
    } else {
      await controller.updateProduct(companion);
    }
    
    // Trigger background sync for images if needed (Fire & Forget)
    // "The SyncService must trigger the image upload after the product data is saved locally."
    ref.read(syncServiceProvider).uploadPendingImages('tenant_1');

    if (mounted) Navigator.pop(context);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? 'New Product' : 'Edit Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Image Picker UI
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                       if (_imageFile != null)
                        Image.file(_imageFile!, fit: BoxFit.cover, width: 150, height: 150)
                      else if (_existingImagePath != null)
                         Image.file(File(_existingImagePath!), fit: BoxFit.cover, width: 150, height: 150, errorBuilder: (_,__,___) => const Icon(Icons.broken_image))
                      else if (_existingImageUrl != null)
                        Image.network(_existingImageUrl!, fit: BoxFit.cover, width: 150, height: 150) // If we want to show cloud img
                      else
                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                            Text('Add Photo', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                        
                      // Progress Bar
                      if (_isUploading)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: ShopifyUploadProgress(progress: _uploadProgress, isError: _isUploadError),
                        ),
                        
                      // Retry Button if Upload Failed (Local Exists, Cloud Missing)
                      if (!_isUploading && 
                          ((_imageFile != null && _existingImageUrl == null) || 
                           (_existingImagePath != null && _existingImageUrl == null))) ...[
                          Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 16,
                              child: IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.orange, size: 16),
                                onPressed: _saveProduct, // Just calling save triggers upload logic again
                                tooltip: 'Retry Upload',
                              ),
                            ),
                          )
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price (MMK)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _unitType,
                decoration: const InputDecoration(labelText: 'Unit Type', border: OutlineInputBorder()),
                items: ['UNIT', 'WEIGHT'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _unitType = v!),
              ),
              const SizedBox(height: 16),
              
              SwitchListTile(
                title: const Text('Tax Exempt'),
                value: _isTaxExempt,
                onChanged: (v) => setState(() => _isTaxExempt = v),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white
                  ),
                  child: _isUploading 
                    ? const Text('Uploading...') 
                    : const Text('Save Product'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
