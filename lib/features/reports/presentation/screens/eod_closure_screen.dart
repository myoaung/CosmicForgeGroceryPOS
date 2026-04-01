import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery/core/localization/mmk_rounding.dart';
import 'package:grocery/core/providers/sync_provider.dart';
import 'package:grocery/features/licensing/data/models/license_model.dart';
import 'package:grocery/features/licensing/presentation/screens/license_status_screen.dart';
import 'package:grocery/features/reports/data/models/eod_report_model.dart';
import 'package:uuid/uuid.dart';

// ── Branding ──────────────────────────────────────────────────────────────────
class _Clr {
  static const navy       = Color(0xFF1A2A4A);
  static const navyLight  = Color(0xFF243660);
  static const silver     = Color(0xFFB0BEC5);
  static const silverDark = Color(0xFF78909C);
  static const emerald    = Color(0xFF00C853);
  static const amber      = Color(0xFFFFAB00);
  static const red        = Color(0xFFD50000);
}

/// Step-by-step End-of-Day "Close the Register" wizard.
///
/// Flow:
///   Step 0 — License gate (shown automatically if expired)
///   Step 1 — Review sales summary
///   Step 2 — Enter physical cash count
///   Step 3 — Confirmation & sync status check
///   Step 4 — Finalize (blocked on tenantError / forbidden sync state)
class EodClosureScreen extends ConsumerStatefulWidget {
  const EodClosureScreen({
    super.key,
    required this.license,
    required this.storeId,
    required this.tenantId,
    required this.rawTransactionAmounts,
    required this.taxCollected,
    this.onEodComplete,
  });

  /// Current tenant license — validated before allowing EOD finalization.
  final LicenseModel license;

  final String storeId;
  final String tenantId;

  /// Raw (un-rounded) transaction totals for the current shift.
  final List<double> rawTransactionAmounts;

  final double taxCollected;

  /// Called with the completed [EodReportModel] on successful finalization.
  final void Function(EodReportModel)? onEodComplete;

  @override
  ConsumerState<EodClosureScreen> createState() => _EodClosureScreenState();
}

class _EodClosureScreenState extends ConsumerState<EodClosureScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _cashCountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0;
  double? _cashActual;
  String? _operatorNotes;

  static const _totalSteps = 3; // Steps 1–3 (0 = license gate, shown separately)

  @override
  void dispose() {
    _pageController.dispose();
    _cashCountController.dispose();
    super.dispose();
  }

  void _next() {
    setState(() => _currentStep++);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  EodReportModel _buildReport(SyncState syncState) {
    return EodReportModel.fromShiftData(
      closureId: const Uuid().v4(),
      storeId: widget.storeId,
      tenantId: widget.tenantId,
      closedAt: DateTime.now().toUtc(),
      rawTransactionAmounts: widget.rawTransactionAmounts,
      taxCollected: widget.taxCollected,
      cashActual: _cashActual ?? 0.0,
      syncStatusAtClosure: syncState.status.name,
      operatorNotes: _operatorNotes,
    );
  }

  bool _canFinalize(SyncState syncState) =>
      syncState.status != SyncStatus.tenantError &&
      syncState.status != SyncStatus.forbidden;

  @override
  Widget build(BuildContext context) {
    // ── License gate ────────────────────────────────────────────────────────
    if (!widget.license.isValid) {
      return LicenseStatusScreen(license: widget.license);
    }

    final syncState = ref.watch(syncStateProvider);

    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _Clr.navy,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      child: Scaffold(
        backgroundColor: _Clr.navy,
        appBar: AppBar(
          backgroundColor: _Clr.navyLight,
          elevation: 0,
          leading: _currentStep > 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white70),
                  onPressed: _back,
                )
              : null,
          title: const Row(
            children: [
              Icon(Icons.point_of_sale_rounded, color: _Clr.silver, size: 18),
              SizedBox(width: 10),
              Text(
                'CLOSE REGISTER',
                style: TextStyle(
                  color: _Clr.silver,
                  fontSize: 13,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _StepPip(current: _currentStep, total: _totalSteps),
            ),
          ],
        ),
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _Step1SalesSummary(
              storeId: widget.storeId,
              rawAmounts: widget.rawTransactionAmounts,
              taxCollected: widget.taxCollected,
              onNext: _next,
            ),
            _Step2CashCount(
              formKey: _formKey,
              controller: _cashCountController,
              onNext: (cash, notes) {
                setState(() {
                  _cashActual = cash;
                  _operatorNotes = notes;
                });
                _next();
              },
            ),
            _Step3Confirmation(
              report: _buildReport(syncState),
              syncState: syncState,
              canFinalize: _canFinalize(syncState),
              onFinalize: () =>
                  widget.onEodComplete?.call(_buildReport(syncState)),
              onBack: _back,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step Widgets ─────────────────────────────────────────────────────────────

class _Step1SalesSummary extends StatelessWidget {
  const _Step1SalesSummary({
    required this.storeId,
    required this.rawAmounts,
    required this.taxCollected,
    required this.onNext,
  });
  final String storeId;
  final List<double> rawAmounts;
  final double taxCollected;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final totalRaw = rawAmounts.fold<double>(0, (s, a) => s + a);
    final totalRounded = rawAmounts.fold<int>(0, (s, a) => s + a.roundMm);

    return _WizardPage(
      stepLabel: 'Step 1 of 3',
      title: 'Today\'s Sales',
      subtitle: 'Review the shift summary before counting the drawer.',
      content: Column(
        children: [
          _SummaryCard(rows: [
            ('Transactions', '${rawAmounts.length}'),
            ('Gross Sales (Raw)', '${totalRaw.toStringAsFixed(0)} Ks'),
            ('5-Kyat Rounded Total', '${totalRounded.toStringAsFixed(0)} Ks'),
            ('Tax Collected', '${taxCollected.toStringAsFixed(0)} Ks'),
          ]),
          const SizedBox(height: 8),
          const Text(
            'The "Expected Cash" in the next step is the 5-Kyat rounded total.',
            style: TextStyle(fontSize: 11, color: _Clr.silverDark),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      primaryAction: _NavButton(label: 'Count Cash →', onTap: onNext),
    );
  }
}

class _Step2CashCount extends StatefulWidget {
  const _Step2CashCount({
    required this.formKey,
    required this.controller,
    required this.onNext,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final void Function(double cash, String? notes) onNext;

  @override
  State<_Step2CashCount> createState() => _Step2CashCountState();
}

class _Step2CashCountState extends State<_Step2CashCount> {
  final _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return _WizardPage(
      stepLabel: 'Step 2 of 3',
      title: 'Count the Drawer',
      subtitle: 'Enter the physical cash found in the register.',
      content: Form(
        key: widget.formKey,
        child: Column(
          children: [
            TextFormField(
              controller: widget.controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              style: const TextStyle(color: Colors.white, fontSize: 22),
              decoration: InputDecoration(
                labelText: 'Physical Cash Count (Ks)',
                labelStyle: const TextStyle(color: _Clr.silver),
                suffixText: 'Ks',
                suffixStyle: const TextStyle(color: _Clr.silver),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _Clr.silverDark),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _Clr.emerald, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _Clr.red),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _Clr.red, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: _Clr.navyLight,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter a cash amount.';
                final parsed = double.tryParse(v);
                if (parsed == null || parsed < 0) {
                  return 'Enter a valid positive number.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Operator Notes (optional)',
                labelStyle: const TextStyle(color: _Clr.silverDark),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _Clr.silverDark.withAlpha(80)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _Clr.silver),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: _Clr.navyLight.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
      primaryAction: _NavButton(
        label: 'Review →',
        onTap: () {
          if (widget.formKey.currentState?.validate() ?? false) {
            widget.onNext(
              double.parse(widget.controller.text),
              _notesController.text.isEmpty ? null : _notesController.text,
            );
          }
        },
      ),
    );
  }
}

class _Step3Confirmation extends StatelessWidget {
  const _Step3Confirmation({
    required this.report,
    required this.syncState,
    required this.canFinalize,
    required this.onFinalize,
    required this.onBack,
  });
  final EodReportModel report;
  final SyncState syncState;
  final bool canFinalize;
  final VoidCallback onFinalize;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final balanceColor = report.isBalanced ? _Clr.emerald : _Clr.red;

    return _WizardPage(
      stepLabel: 'Step 3 of 3',
      title: 'Confirm & Finalize',
      subtitle: 'Review the reconciliation before closing.',
      content: Column(
        children: [
          _SummaryCard(rows: [
            ('Expected Cash', '${report.cashExpected.toStringAsFixed(0)} Ks'),
            ('Actual Cash', '${report.cashActual.toStringAsFixed(0)} Ks'),
            ('Discrepancy',
                '${report.discrepancy >= 0 ? '+' : ''}${report.discrepancy.toStringAsFixed(0)} Ks'),
            ('Rounding Adj.', '${report.roundingAdjustment.toStringAsFixed(2)} Ks'),
            ('Bank Transfer Ready', '${report.bankTransferReady} Ks'),
          ]),
          const SizedBox(height: 12),
          // Balance indicator
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: balanceColor),
              borderRadius: BorderRadius.circular(24),
              color: balanceColor.withAlpha(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  report.isBalanced
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded,
                  color: balanceColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  report.isBalanced ? 'BALANCED' : 'DISCREPANCY DETECTED',
                  style: TextStyle(
                    color: balanceColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Sync status at closure
          _SyncStatusBanner(syncState: syncState),
          if (!canFinalize) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _Clr.red.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _Clr.red.withAlpha(120)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block_rounded, color: _Clr.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'EOD finalization is blocked. '
                      'A ${syncState.status.name} error was detected. '
                      'Contact your administrator before closing.',
                      style: const TextStyle(
                          color: _Clr.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      primaryAction: canFinalize
          ? _NavButton(
              label: '✓ Finalize EOD',
              color: _Clr.emerald,
              onTap: onFinalize,
            )
          : const _NavButton(
              label: 'Blocked — Fix Sync Error',
              color: _Clr.red,
              onTap: null, // disabled
            ),
    );
  }
}

// ── Shared Layout Widgets ─────────────────────────────────────────────────────

class _WizardPage extends StatelessWidget {
  const _WizardPage({
    required this.stepLabel,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.primaryAction,
  });
  final String stepLabel;
  final String title;
  final String subtitle;
  final Widget content;
  final Widget primaryAction;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(stepLabel,
              style: const TextStyle(
                  color: _Clr.silverDark,
                  fontSize: 11,
                  letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle,
              style:
                  const TextStyle(color: _Clr.silverDark, fontSize: 13)),
          const SizedBox(height: 24),
          content,
          const SizedBox(height: 32),
          primaryAction,
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _Clr.navyLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Clr.silverDark.withAlpha(60)),
      ),
      child: Column(
        children: rows.map((row) {
          final (label, value) = row;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: const TextStyle(color: _Clr.silverDark, fontSize: 13)),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SyncStatusBanner extends StatelessWidget {
  const _SyncStatusBanner({required this.syncState});
  final SyncState syncState;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (syncState.status) {
      SyncStatus.synced    => (_Clr.emerald, 'Sync: ✓ Synced at closure'),
      SyncStatus.pending   => (_Clr.amber,   'Sync: ${syncState.pendingCount} pending'),
      SyncStatus.offline   => (_Clr.amber,   'Sync: Offline (recorded locally)'),
      SyncStatus.tenantError => (_Clr.red,   'Sync: Tenant mismatch error'),
      SyncStatus.forbidden   => (_Clr.red,   'Sync: 403 Forbidden'),
    };
    return Row(
      children: [
        Icon(Icons.cloud_sync_rounded, color: color, size: 15),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF1565C0),
  });
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: onTap != null ? color : _Clr.silverDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }
}

class _StepPip extends StatelessWidget {
  const _StepPip({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: active ? 16 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: active ? _Clr.emerald : _Clr.silverDark,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}


