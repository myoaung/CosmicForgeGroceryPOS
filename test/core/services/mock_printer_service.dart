import 'package:mockito/mockito.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

// Manual Mock to avoid build_runner if environment is flaky, 
// but since I am writing a test file that uses generate mocks, I might just rely on that.
// construct is simplistic here.
class MockPrinterService extends Mock implements BlueThermalPrinter {
    @override
    Future<bool?> get isConnected => super.noSuchMethod(Invocation.getter(#isConnected), returnValue: Future.value(false));

    @override
    Future<List<BluetoothDevice>> getBondedDevices() => super.noSuchMethod(
        Invocation.method(#getBondedDevices, []),
        returnValue: Future.value(<BluetoothDevice>[]));

    @override
    Future<bool?> connect(BluetoothDevice? device) => super.noSuchMethod(
        Invocation.method(#connect, [device]),
        returnValue: Future.value(true));

    @override
    Future<bool?> disconnect() => super.noSuchMethod(
        Invocation.method(#disconnect, []),
        returnValue: Future.value(true));

    @override
    Future<dynamic> printImageBytes(List<int>? bytes) => super.noSuchMethod(
        Invocation.method(#printImageBytes, [bytes]),
        returnValue: Future.value());
        
    @override
    Future<dynamic> paperCut() => super.noSuchMethod(
        Invocation.method(#paperCut, []),
        returnValue: Future.value());
}
