import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery/core/providers/sync_provider.dart';

/// A compact animated widget that communicates the current sync health at a
/// glance, without requiring the user to open a detailed sync panel.
///
/// ## States
/// | [SyncStatus]      | Visual                                 |
/// |-------------------|----------------------------------------|
/// | `synced`          | 🟢 Pulsing green dot + "Synced"        |
/// | `pending`         | 🟡 Amber dot + "N pending" badge       |
/// | `offline`         | 🟡 Static amber + "Offline" label      |
/// | `tenantError`     | 🔴 Flashing red icon + "Sync Blocked"  |
/// | `forbidden`       | 🔴 Flashing red icon + "Access Denied" |
///
/// Place in an [AppBar], admin sidebar, or floating status bar.
class SyncHeartbeatWidget extends ConsumerStatefulWidget {
  const SyncHeartbeatWidget({super.key});

  @override
  ConsumerState<SyncHeartbeatWidget> createState() =>
      _SyncHeartbeatWidgetState();
}

class _SyncHeartbeatWidgetState extends ConsumerState<SyncHeartbeatWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateProvider);
    return _HeartbeatView(
      syncState: syncState,
      pulse: _pulse,
      controller: _controller,
    );
  }
}

// ── Internal StatelessWidget for easy testing ─────────────────────────────────

class _HeartbeatView extends StatelessWidget {
  const _HeartbeatView({
    required this.syncState,
    required this.pulse,
    required this.controller,
  });

  final SyncState syncState;
  final Animation<double> pulse;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label, shouldPulse, shouldFlash) =
        _resolveVisuals(syncState);

    // Start/stop the animation based on state.
    if (shouldPulse || shouldFlash) {
      if (!controller.isAnimating) controller.repeat(reverse: shouldPulse);
    } else {
      if (controller.isAnimating) controller.stop();
    }

    return Tooltip(
      message: _buildTooltip(syncState),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              final scale = shouldPulse ? pulse.value : 1.0;
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: shouldFlash
                ? _FlashingIcon(color: color, icon: icon)
                : _DotIndicator(color: color, icon: icon, isError: false),
          ),
          const SizedBox(width: 6),
          _LabelBadge(
            label: label,
            color: color,
            count: syncState.status == SyncStatus.pending
                ? syncState.pendingCount
                : null,
          ),
        ],
      ),
    );
  }

  /// Returns `(color, icon, label, shouldPulse, shouldFlash)`.
  (Color, IconData, String, bool, bool) _resolveVisuals(SyncState state) {
    switch (state.status) {
      case SyncStatus.synced:
        return (
          const Color(0xFF00C853), // vivid green
          Icons.cloud_done_rounded,
          'Synced',
          true,  // animate: pulse
          false,
        );
      case SyncStatus.pending:
        return (
          const Color(0xFFFFAB00), // amber
          Icons.cloud_upload_rounded,
          'Pending',
          false,
          false,
        );
      case SyncStatus.offline:
        return (
          const Color(0xFFFFAB00),
          Icons.cloud_off_rounded,
          'Offline',
          false,
          false,
        );
      case SyncStatus.tenantError:
        return (
          const Color(0xFFD50000), // red
          Icons.gpp_bad_rounded,
          'Sync Blocked',
          false,
          true, // animate: flash
        );
      case SyncStatus.forbidden:
        return (
          const Color(0xFFD50000),
          Icons.lock_rounded,
          'Access Denied',
          false,
          true,
        );
    }
  }

  String _buildTooltip(SyncState state) {
    final base = switch (state.status) {
      SyncStatus.synced    => 'All data synced to cloud',
      SyncStatus.pending   => '${state.pendingCount} record(s) waiting to sync',
      SyncStatus.offline   => 'Device is offline — changes stored locally',
      SyncStatus.tenantError => 'Sync blocked: tenant mismatch detected',
      SyncStatus.forbidden => 'Sync blocked: server returned 403 Forbidden',
    };
    if (state.lastErrorMessage != null) {
      return '$base\n${state.lastErrorMessage}';
    }
    return base;
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({
    required this.color,
    required this.icon,
    required this.isError,
  });
  final Color color;
  final IconData icon;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          shape: BoxShape.circle,
          border: Border.all(color: color.withAlpha(120), width: 1.5),
        ),
        child: Icon(icon, color: color, size: 16),
      );
}

class _FlashingIcon extends StatefulWidget {
  const _FlashingIcon({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  State<_FlashingIcon> createState() => _FlashingIconState();
}

class _FlashingIconState extends State<_FlashingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash;

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _flash,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: widget.color.withAlpha(40),
            shape: BoxShape.circle,
          ),
          child: Icon(widget.icon, color: widget.color, size: 18),
        ),
      );
}

class _LabelBadge extends StatelessWidget {
  const _LabelBadge({
    required this.label,
    required this.color,
    this.count,
  });
  final String label;
  final Color color;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final displayLabel =
        count != null && count! > 0 ? '$label ($count)' : label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        displayLabel,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
