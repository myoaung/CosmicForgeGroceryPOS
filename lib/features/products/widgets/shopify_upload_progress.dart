import 'package:flutter/material.dart';

class ShopifyUploadProgress extends StatelessWidget {
  final double progress; // Value between 0.0 and 1.0
  final bool isError;

  const ShopifyUploadProgress({
    super.key, 
    required this.progress,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: isError ? Colors.red : const Color(0xFF008060), // Shopify Brand Green or Red for Error
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
