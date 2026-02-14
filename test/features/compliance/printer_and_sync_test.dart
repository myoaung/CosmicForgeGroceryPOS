import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:grocery/core/services/supabase_storage_service.dart';
import 'dart:io';

// Annotation to generate mocks
@GenerateMocks([BlueThermalPrinter, SupabaseStorageService])
import 'printer_and_sync_test.mocks.dart';

void main() {
  group('Thermal Printer & Sync Mock Tests', () {
    late MockBlueThermalPrinter mockPrinter;
    late MockSupabaseStorageService mockStorage;

    setUp(() {
      mockPrinter = MockBlueThermalPrinter();
      mockStorage = MockSupabaseStorageService();
    });

    test('Thermal Printer Handshake (AppConnected check)', () async {
      // Stubbing
      when(mockPrinter.isConnected).thenAnswer((_) async => true);

      // Execution
      final isConnected = await mockPrinter.isConnected;

      // Verification
      expect(isConnected, true);
      verify(mockPrinter.isConnected).called(1);
    });

    test('Cloud Sync Upload (Deterministic Mock)', () async {
      // Data
      final dummyFile = File('dummy.jpg');
      final tenantId = 'tenant_123';
      final productId = 'prod_456';
      final expectedUrl = 'https://cloud.com/tenant_123/prod_456.jpg';

      // Stubbing
      when(mockStorage.uploadProductImage(
        imageFile: anyNamed('imageFile'),
        tenantId: anyNamed('tenantId'),
        productId: anyNamed('productId'),
      )).thenAnswer((_) async => expectedUrl);

      // Execution
      final result = await mockStorage.uploadProductImage(
          imageFile: dummyFile, 
          tenantId: tenantId, 
          productId: productId
      );

      // Verification
      expect(result, expectedUrl);
      verify(mockStorage.uploadProductImage(
        imageFile: dummyFile,
        tenantId: tenantId,
        productId: productId,
      )).called(1);
    });
  });
}
