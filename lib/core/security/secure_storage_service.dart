import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SecureStoragePort {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class FlutterSecureStoragePort implements SecureStoragePort {
  FlutterSecureStoragePort([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

class InMemorySecureStoragePort implements SecureStoragePort {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _data.clear();
  }
}

class SecureStorageService {
  SecureStorageService({SecureStoragePort? storage})
      : _storage = storage ?? FlutterSecureStoragePort();

  static const String accessTokenKey = 'auth.access_token';
  static const String refreshTokenKey = 'auth.refresh_token';
  static const String sessionIdKey = 'auth.session_id';
  static const String databaseKey = 'db.sqlcipher.key';

  final SecureStoragePort _storage;

  Future<void> persistSession(Session session) async {
    await _storage.write(accessTokenKey, session.accessToken);
    final refreshToken = session.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(refreshTokenKey, refreshToken);
    }
    // Store a session-granular identifier (first 16 chars of access token hash)
    // so we have a stable, revocable reference — not just the user UUID.
    final sessionFingerprint = session.accessToken.length > 16
        ? session.accessToken.substring(0, 16)
        : session.accessToken;
    await _storage.write(sessionIdKey, sessionFingerprint);
  }

  Future<String?> readAccessToken() => _storage.read(accessTokenKey);
  Future<String?> readRefreshToken() => _storage.read(refreshTokenKey);

  Future<void> clearSession() async {
    await _storage.delete(accessTokenKey);
    await _storage.delete(refreshTokenKey);
    await _storage.delete(sessionIdKey);
  }

  Future<String> getOrCreateDatabaseKey() async {
    final existing = await _storage.read(databaseKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final bytes = List<int>.generate(48, (_) => Random.secure().nextInt(256));
    final newKey = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(databaseKey, newKey);
    return newKey;
  }
}
