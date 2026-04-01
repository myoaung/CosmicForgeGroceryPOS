import 'package:flutter/material.dart';

class LicenseCertificateTemplate extends StatelessWidget {
  final String licenseeName;
  final String tenantId;
  final String deviceId;
  final DateTime issueDate;
  final DateTime expiryDate;
  final String authorizedStores;

  const LicenseCertificateTemplate({
    super.key,
    required this.licenseeName,
    required this.tenantId,
    required this.deviceId,
    required this.issueDate,
    required this.expiryDate,
    required this.authorizedStores,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade800, width: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, size: 64, color: Colors.blueGrey.shade800),
          const SizedBox(height: 16),
          Text(
            'COSMIC FORGE POS',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.blueGrey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'OFFICIAL SOFTWARE LICENSE CERTIFICATE',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 32),
          const Text(
            'This certifies that the following entity is officially licensed\n'
            'to use the Cosmic Forge Point of Sale software suite.',
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 32),
          _buildRow('Licensee:', licenseeName),
          const SizedBox(height: 12),
          _buildRow('Tenant ID:', tenantId),
          const SizedBox(height: 12),
          _buildRow('Authorized Stores:', authorizedStores),
          const SizedBox(height: 12),
          _buildRow('Hardware Binding (Device ID):', deviceId),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateInfo('Issue Date:', issueDate),
              _buildDateInfo('Expiry Date:', expiryDate),
            ],
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                   Container(width: 150, height: 1, color: Colors.black),
                   const SizedBox(height: 8),
                   const Text('Authorized Signature'),
                ],
              ),
              const Icon(Icons.qr_code_2, size: 80),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 250,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildDateInfo(String label, DateTime date) {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(width: 8),
        Text(dateStr),
      ],
    );
  }
}
