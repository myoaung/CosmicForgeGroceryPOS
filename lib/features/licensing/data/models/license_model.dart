import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Represents a Cosmic Forge POS software license certificate.
///
/// The [digitalSignature] is an HMAC-SHA256 hex digest that binds the key
/// license fields together. Verify it with [verifySignature] before trusting
/// the license data.
class LicenseModel {
  /// Unique identifier for this license (UUID).
  final String licenseId;

  /// Tenant this license belongs to (UUID).
  final String tenantId;

  /// Human-readable name of the licensee (e.g. business name).
  final String licenseeName;

  /// Date the license was issued.
  final DateTime issueDate;

  /// Date after which the license is no longer valid.
  final DateTime expiryDate;

  /// Maximum number of simultaneously active POS devices allowed.
  final int deviceLimit;

  /// HMAC-SHA256 hex digest of the canonical license payload.
  ///
  /// Canonical form: `"$licenseId|$tenantId|${expiryDate.toIso8601String()}|$deviceLimit"`
  final String digitalSignature;

  const LicenseModel({
    required this.licenseId,
    required this.tenantId,
    required this.licenseeName,
    required this.issueDate,
    required this.expiryDate,
    required this.deviceLimit,
    required this.digitalSignature,
  });

  // ---------------------------------------------------------------------------
  // Validity
  // ---------------------------------------------------------------------------

  /// `true` when the current UTC time is before [expiryDate].
  bool get isValid => DateTime.now().toUtc().isBefore(expiryDate.toUtc());

  /// Returns how many days remain until expiry (negative if already expired).
  int get daysUntilExpiry =>
      expiryDate.toUtc().difference(DateTime.now().toUtc()).inDays;

  // ---------------------------------------------------------------------------
  // Signature helpers
  // ---------------------------------------------------------------------------

  /// Canonical payload string used for HMAC computation.
  String _canonicalPayload() =>
      '$licenseId|$tenantId|${expiryDate.toUtc().toIso8601String()}|$deviceLimit';

  /// Generates an HMAC-SHA256 signature for the given [secretKey].
  static String generateSignature({
    required String licenseId,
    required String tenantId,
    required DateTime expiryDate,
    required int deviceLimit,
    required String secretKey,
  }) {
    final payload =
        '$licenseId|$tenantId|${expiryDate.toUtc().toIso8601String()}|$deviceLimit';
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    return hmac.convert(utf8.encode(payload)).toString();
  }

  /// Verifies [digitalSignature] against the provided [secretKey].
  bool verifySignature(String secretKey) {
    final expected = generateSignature(
      licenseId: licenseId,
      tenantId: tenantId,
      expiryDate: expiryDate,
      deviceLimit: deviceLimit,
      secretKey: secretKey,
    );
    // Constant-time comparison to prevent timing attacks.
    if (expected.length != digitalSignature.length) return false;
    var result = 0;
    for (var i = 0; i < expected.length; i++) {
      result |= expected.codeUnitAt(i) ^ digitalSignature.codeUnitAt(i);
    }
    return result == 0;
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  factory LicenseModel.fromJson(Map<String, dynamic> json) => LicenseModel(
        licenseId: json['license_id'] as String,
        tenantId: json['tenant_id'] as String,
        licenseeName: json['licensee_name'] as String,
        issueDate: DateTime.parse(json['issue_date'] as String),
        expiryDate: DateTime.parse(json['expiry_date'] as String),
        deviceLimit: json['device_limit'] as int,
        digitalSignature: json['digital_signature'] as String,
      );

  Map<String, dynamic> toJson() => {
        'license_id': licenseId,
        'tenant_id': tenantId,
        'licensee_name': licenseeName,
        'issue_date': issueDate.toUtc().toIso8601String(),
        'expiry_date': expiryDate.toUtc().toIso8601String(),
        'device_limit': deviceLimit,
        'digital_signature': digitalSignature,
      };

  @override
  String toString() =>
      'LicenseModel(licenseId: $licenseId, tenantId: $tenantId, '
      'licenseeName: $licenseeName, expiryDate: $expiryDate, '
      'deviceLimit: $deviceLimit, isValid: $isValid)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LicenseModel &&
          licenseId == other.licenseId &&
          tenantId == other.tenantId &&
          digitalSignature == other.digitalSignature;

  @override
  int get hashCode => Object.hash(licenseId, tenantId, digitalSignature);
}
