import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/security/secure_storage_service.dart';

void main() {
  test('getOrCreateDatabaseKey persists generated key', () async {
    final service = SecureStorageService(storage: InMemorySecureStoragePort());
    final first = await service.getOrCreateDatabaseKey();
    final second = await service.getOrCreateDatabaseKey();

    expect(first, isNotEmpty);
    expect(second, first);
    expect(first.length, 96); // 48 bytes hex encoded
  });

  test('clearSession removes persisted tokens', () async {
    final service = SecureStorageService(storage: InMemorySecureStoragePort());
    await service.clearSession();
    expect(await service.readAccessToken(), isNull);
    expect(await service.readRefreshToken(), isNull);
  });
}
