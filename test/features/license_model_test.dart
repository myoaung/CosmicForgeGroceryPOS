// test/features/license_model_test.dart
//
// Unit tests for LicenseModel:
//   - HMAC-SHA256 digital signature generation & verification
//   - isValid expiry logic
//   - JSON round-trip fidelity

import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/features/licensing/data/models/license_model.dart';

void main() {
  // ── Fixtures ────────────────────────────────────────────────────────────────
  const testKey        = 'super-secret-signing-key-for-tests';
  const licenseId      = 'lic-0000-0001-0002-0003';
  const tenantId       = 'tenant-aaaa-bbbb-cccc-dddd';
  const licenseeName   = 'Golden Dragon Grocery';
  const deviceLimit    = 5;

  final issueDate      = DateTime.utc(2025, 1,  1);
  final expiryFuture   = DateTime.utc(2099, 12, 31); // far future — valid
  final expiryPast     = DateTime.utc(2020,  1,  1); // past — expired

  // Helper to build a LicenseModel quickly in tests.
  LicenseModel build({
    required DateTime expiry,
    String? overrideSignature,
  }) {
    final sig = overrideSignature ??
        LicenseModel.generateSignature(
          licenseId: licenseId,
          tenantId: tenantId,
          expiryDate: expiry,
          deviceLimit: deviceLimit,
          secretKey: testKey,
        );

    return LicenseModel(
      licenseId: licenseId,
      tenantId: tenantId,
      licenseeName: licenseeName,
      issueDate: issueDate,
      expiryDate: expiry,
      deviceLimit: deviceLimit,
      digitalSignature: sig,
    );
  }

  // ── Signature Generation & Verification ─────────────────────────────────────
  group('Digital Signature', () {
    test('generateSignature produces a 64-character hex string', () {
      final sig = LicenseModel.generateSignature(
        licenseId: licenseId,
        tenantId: tenantId,
        expiryDate: expiryFuture,
        deviceLimit: deviceLimit,
        secretKey: testKey,
      );

      expect(sig.length, 64,
          reason: 'SHA-256 HMAC hex output must always be 64 characters.');
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(sig), isTrue,
          reason: 'Output must be lowercase hex.');
    });

    test('verifySignature returns true for a valid license', () {
      final lic = build(expiry: expiryFuture);
      expect(lic.verifySignature(testKey), isTrue);
    });

    test('verifySignature returns false for a tampered signature', () {
      final lic = build(
        expiry: expiryFuture,
        overrideSignature: 'deadbeef' * 8, // 64 chars but wrong value
      );
      expect(lic.verifySignature(testKey), isFalse);
    });

    test('verifySignature returns false when wrong key is used', () {
      final lic = build(expiry: expiryFuture);
      expect(lic.verifySignature('wrong-key'), isFalse);
    });

    test('generateSignature is deterministic for identical inputs', () {
      final sig1 = LicenseModel.generateSignature(
        licenseId: licenseId,
        tenantId: tenantId,
        expiryDate: expiryFuture,
        deviceLimit: deviceLimit,
        secretKey: testKey,
      );
      final sig2 = LicenseModel.generateSignature(
        licenseId: licenseId,
        tenantId: tenantId,
        expiryDate: expiryFuture,
        deviceLimit: deviceLimit,
        secretKey: testKey,
      );
      expect(sig1, equals(sig2));
    });

    test('different deviceLimit produces different signature', () {
      final sig5 = LicenseModel.generateSignature(
        licenseId: licenseId,
        tenantId: tenantId,
        expiryDate: expiryFuture,
        deviceLimit: 5,
        secretKey: testKey,
      );
      final sig10 = LicenseModel.generateSignature(
        licenseId: licenseId,
        tenantId: tenantId,
        expiryDate: expiryFuture,
        deviceLimit: 10,
        secretKey: testKey,
      );
      expect(sig5, isNot(equals(sig10)));
    });
  });

  // ── Expiry / isValid ─────────────────────────────────────────────────────────
  group('Expiry & Validity', () {
    test('isValid returns true for a future expiry date', () {
      expect(build(expiry: expiryFuture).isValid, isTrue);
    });

    test('isValid returns false for a past expiry date', () {
      expect(build(expiry: expiryPast).isValid, isFalse);
    });

    test('daysUntilExpiry is positive for future license', () {
      expect(build(expiry: expiryFuture).daysUntilExpiry, greaterThan(0));
    });

    test('daysUntilExpiry is negative for expired license', () {
      expect(build(expiry: expiryPast).daysUntilExpiry, lessThan(0));
    });
  });

  // ── JSON Round-Trip ──────────────────────────────────────────────────────────
  group('JSON serialization', () {
    test('toJson / fromJson round-trip preserves all fields', () {
      final original = build(expiry: expiryFuture);
      final decoded  = LicenseModel.fromJson(original.toJson());

      expect(decoded.licenseId,        equals(original.licenseId));
      expect(decoded.tenantId,         equals(original.tenantId));
      expect(decoded.licenseeName,     equals(original.licenseeName));
      expect(decoded.deviceLimit,      equals(original.deviceLimit));
      expect(decoded.digitalSignature, equals(original.digitalSignature));
      expect(decoded.issueDate.toUtc(),  equals(original.issueDate.toUtc()));
      expect(decoded.expiryDate.toUtc(), equals(original.expiryDate.toUtc()));
    });

    test('fromJson-decoded model passes signature verification', () {
      final original = build(expiry: expiryFuture);
      final decoded  = LicenseModel.fromJson(original.toJson());

      expect(decoded.verifySignature(testKey), isTrue,
          reason: 'Signature must survive a JSON round-trip.');
    });

    test('fromJson-decoded expired model is still correctly identified', () {
      final expired = build(expiry: expiryPast);
      final decoded = LicenseModel.fromJson(expired.toJson());

      expect(decoded.isValid, isFalse);
    });
  });
}
