import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:grocery/core/services/receipt_service.dart';
import 'package:grocery/core/services/store_service.dart';
import 'mock_printer_service.dart';

// Mock StoreService manually for now
class MockStoreService extends Mock implements StoreService {
    @override
    Future<void> logAudit({required String actionType, required String description}) => super.noSuchMethod(
        Invocation.method(#logAudit, [], {#actionType: actionType, #description: description}),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
    );
}

void main() {
  late ReceiptService service;
  late MockPrinterService mockPrinter;

  setUp(() {
    mockPrinter = MockPrinterService();
    service = ReceiptService(printer: mockPrinter);
  });

  test('connects to device if not connected', () async {
    final device = BluetoothDevice('Test Device', '00:00:00:00:00:00');
    
    // Stubbing using Mockito's when. 
    // Note: for manual mocks extending Mock, this works if noSuchMethod is delegating.
    when(mockPrinter.isConnected).thenAnswer((_) async => false);
    when(mockPrinter.connect(device)).thenAnswer((_) async => true);

    final result = await service.connect(device);

    expect(result, true);
    verify(mockPrinter.connect(device)).called(1);
  });
  
  test('does not reconnect if already connected', () async {
    final device = BluetoothDevice('Test Device', '00:00:00:00:00:00');
    
    when(mockPrinter.isConnected).thenAnswer((_) async => true);

    final result = await service.connect(device);

    expect(result, true);
    verifyNever(mockPrinter.connect(device));
  });
}
