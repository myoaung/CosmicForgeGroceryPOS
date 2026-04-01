import 'package:flutter/material.dart';

import '../../data/models/license_model.dart';

/// Navy/Silver color constants matching the Cosmic Forge brand palette.
class _LicenseColors {
  static const navy = Color(0xFF1A2A4A);
  static const navyLight = Color(0xFF243660);
  static const silver = Color(0xFFB0BEC5);
  static const silverDark = Color(0xFF78909C);
  static const activeGreen = Color(0xFF00C853);
  static const expiredRed = Color(0xFFD50000);
}

/// A minimalist "License Status" screen using the Navy/Silver brand palette.
///
/// Pass a [LicenseModel] to display the full certificate details, or `null`
/// to show a loading/no-license state.
class LicenseStatusScreen extends StatelessWidget {
  final LicenseModel? license;

  const LicenseStatusScreen({super.key, this.license});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _LicenseColors.navy,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      child: Scaffold(
        backgroundColor: _LicenseColors.navy,
        appBar: AppBar(
          backgroundColor: _LicenseColors.navyLight,
          title: Row(
            children: [
              Icon(Icons.verified_user_rounded,
                  color: _LicenseColors.silver, size: 20),
              const SizedBox(width: 10),
              Text(
                'SOFTWARE LICENSE',
                style: TextStyle(
                  color: _LicenseColors.silver,
                  fontSize: 14,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          elevation: 0,
        ),
        body: license == null
            ? _buildNoLicense()
            : _buildLicenseDetails(license!),
      ),
    );
  }

  Widget _buildNoLicense() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 64, color: _LicenseColors.silverDark),
            const SizedBox(height: 16),
            Text(
              'No License Found',
              style: TextStyle(
                color: _LicenseColors.silver,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Contact your Cosmic Forge administrator.',
              style: TextStyle(color: _LicenseColors.silverDark, fontSize: 13),
            ),
          ],
        ),
      );

  Widget _buildLicenseDetails(LicenseModel lic) {
    final isValid = lic.isValid;
    final daysLeft = lic.daysUntilExpiry;
    final badgeColor = isValid ? _LicenseColors.activeGreen : _LicenseColors.expiredRed;
    final badgeLabel = isValid ? 'ACTIVE' : 'EXPIRED';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Validity Badge ─────────────────────────────────────────────────
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(30),
                border: Border.all(color: badgeColor, width: 1.5),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: badgeColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    badgeLabel,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          if (isValid)
            Center(
              child: Text(
                '$daysLeft days remaining',
                style: TextStyle(
                  color: _LicenseColors.silverDark,
                  fontSize: 12,
                ),
              ),
            ),

          const SizedBox(height: 32),

          // ── Certificate Card ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _LicenseColors.navyLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _LicenseColors.silverDark.withAlpha(80),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(label: 'LICENSEE'),
                const SizedBox(height: 12),
                _LicenseRow(
                  icon: Icons.business_rounded,
                  label: 'Business',
                  value: lic.licenseeName,
                ),
                _LicenseRow(
                  icon: Icons.fingerprint_rounded,
                  label: 'Tenant ID',
                  value: lic.tenantId,
                  monospace: true,
                ),
                _LicenseRow(
                  icon: Icons.badge_rounded,
                  label: 'License ID',
                  value: lic.licenseId,
                  monospace: true,
                ),
                const SizedBox(height: 20),
                _SectionHeader(label: 'ENTITLEMENTS'),
                const SizedBox(height: 12),
                _LicenseRow(
                  icon: Icons.devices_rounded,
                  label: 'Device Limit',
                  value: '${lic.deviceLimit} device${lic.deviceLimit == 1 ? '' : 's'}',
                ),
                _LicenseRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Issue Date',
                  value: _formatDate(lic.issueDate),
                ),
                _LicenseRow(
                  icon: Icons.event_busy_rounded,
                  label: 'Expiry Date',
                  value: _formatDate(lic.expiryDate),
                  valueColor: isValid ? null : _LicenseColors.expiredRed,
                ),
                const SizedBox(height: 20),
                _SectionHeader(label: 'INTEGRITY'),
                const SizedBox(height: 12),
                _LicenseRow(
                  icon: Icons.key_rounded,
                  label: 'Signature',
                  value: '${lic.digitalSignature.substring(0, 16)}…',
                  monospace: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Internal Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          color: _LicenseColors.silverDark,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      );
}

class _LicenseRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool monospace;
  final Color? valueColor;

  const _LicenseRow({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _LicenseColors.silverDark, size: 18),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: _LicenseColors.silver,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? _LicenseColors.silver,
                fontSize: 13,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
