import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sos_emergency/app/theme/sos_tokens.dart';
import 'package:sos_emergency/app/theme/surface_palette.dart';
import 'package:sos_emergency/domain/models/a2ui_node.dart';
import 'package:sos_emergency/presentation/catalog/shared/sos_chrome.dart';
import 'package:sos_emergency/presentation/catalog/shared/sos_icons.dart';
import 'package:sos_emergency/presentation/surface/binding_resolver.dart';
import 'package:sos_emergency/presentation/surface/surface_actions.dart';
import 'package:sos_emergency/presentation/surface/surface_metrics.dart';
import 'package:sos_emergency/presentation/surface/surface_theme_providers.dart';

const Color _redLight = SosTokens.brandRedLight;
const Color _redDark = SosTokens.brandRedDark;

/// `SOSCallButton` — oversized one-tap call to emergency services. Pinned,
/// never scrolls away; no confirm dialog. Shows live status once connected.
/// Inputs: `emergencyNumber`, `callState` (idle·connecting·active),
/// `callDuration`.
Widget buildSosCallButton(BuildContext context, WidgetRef ref, A2uiNode node) {
  final palette = ref.watch(surfacePaletteProvider);
  final number = ref.resolveString(node, 'emergencyNumber') ?? '911';
  final callState = ref.resolveString(node, 'callState') ?? 'idle';

  if (callState == 'active') {
    final duration = ref.resolveString(node, 'callDuration') ?? '00:00';
    return Semantics(
      liveRegion: true,
      label: 'On call with emergency services $number, duration $duration',
      child: _PanicSquare(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(SosTokens.radiusXl),
          border: Border.all(color: palette.safe, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusDot(color: palette.safe),
                const SizedBox(width: SosTokens.space2),
                Text('ON CALL', style: SosText.label(SosStatus.reached)),
              ],
            ),
            const SizedBox(height: SosTokens.space3),
            Text(duration, style: SosText.telemetry(palette.text)),
            const SizedBox(height: SosTokens.space2),
            Text(
              'Dispatcher · $number',
              style: SosText.body(palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  return Semantics(
    button: true,
    label: 'Call emergency services, $number, now',
    child: GestureDetector(
      onTap: ref.callEmergencyNow,
      child: _PanicSquare(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_redLight, _redDark],
          ),
          borderRadius: BorderRadius.circular(SosTokens.radiusXl),
          boxShadow: [
            BoxShadow(
              color: _redDark.withValues(alpha: 0.5),
              blurRadius: 30,
              spreadRadius: -10,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.call, color: Colors.white, size: 48),
            const SizedBox(height: SosTokens.space2),
            Text(
              number,
              style: const TextStyle(
                fontFamily: SosTokens.fontDisplay,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Text(
              'CALL NOW',
              style: SosText.label(Colors.white).copyWith(letterSpacing: 1.2),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PanicSquare extends StatelessWidget {
  const _PanicSquare({required this.decoration, required this.child});

  final BoxDecoration decoration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = SurfaceMetrics.of(context).panicSize;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: size,
        minHeight: size,
        maxWidth: size,
        maxHeight: size,
      ),
      child: DecoratedBox(
        decoration: decoration,
        child: Center(child: child),
      ),
    );
  }
}

/// `ShareLocationAction` — start/stop a live location broadcast. On/off state is
/// unmistakable. Inputs: `isSharing`, `recipients[]`.
Widget buildShareLocationAction(
  BuildContext context,
  WidgetRef ref,
  A2uiNode node,
) {
  final palette = ref.watch(surfacePaletteProvider);
  final isSharing = ref.resolve(node, 'isSharing') == true;
  final recipients = ref.resolveString(node, 'recipients');

  if (isSharing) {
    return SosCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              StatusDot(color: palette.safe),
              const SizedBox(width: SosTokens.space2),
              Text('BROADCASTING', style: SosText.label(SosStatus.reached)),
            ],
          ),
          const SizedBox(height: SosTokens.space3),
          Text('Location live', style: SosText.headline(palette.text)),
          if (recipients != null) ...[
            const SizedBox(height: SosTokens.space1),
            Text(
              'shared with $recipients',
              style: SosText.body(palette.textMuted),
            ),
          ],
          const SizedBox(height: SosTokens.space4),
          _SecondaryButton(palette: palette, label: 'Stop sharing'),
        ],
      ),
    );
  }

  return SosCard(
    palette: palette,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(SosIcons.resolve('location'), color: palette.textMuted),
            const SizedBox(width: SosTokens.space3),
            Expanded(
              child: Text(
                'Share location',
                style: SosText.headline(palette.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: SosTokens.space1),
        Text(
          'tap to broadcast live GPS',
          style: SosText.body(palette.textMuted),
        ),
        const SizedBox(height: SosTokens.space4),
        _FilledButton(color: palette.safe, label: 'Start sharing'),
      ],
    ),
  );
}

/// `NotifyContactsAction` — alert trusted contacts with situation + location.
/// Shows per-person delivery status.
/// Inputs: `contacts[]{name,relation,status}`.
Widget buildNotifyContactsAction(
  BuildContext context,
  WidgetRef ref,
  A2uiNode node,
) {
  final palette = ref.watch(surfacePaletteProvider);
  final contacts = (ref.resolve(node, 'contacts') as List?) ?? const [];

  if (contacts.isEmpty) {
    return SosCard(
      palette: palette,
      child: EmptyState(
        palette: palette,
        message: 'No trusted contacts yet',
        action: 'Add contact',
      ),
    );
  }

  return SosCard(
    palette: palette,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Alerting contacts…', style: SosText.title(palette.text)),
        const SizedBox(height: SosTokens.space4),
        for (final raw in contacts)
          _ContactRow(
            palette: palette,
            data: (raw as Map).cast<String, Object?>(),
          ),
      ],
    ),
  );
}

/// `ImSafeCancel` — deliberate "I'm okay" control to abort a countdown.
/// Requires press-and-hold so a crash can't trigger it by accident.
/// Inputs: `holdMs`.
Widget buildImSafeCancel(BuildContext context, WidgetRef ref, A2uiNode node) {
  final palette = ref.watch(surfacePaletteProvider);
  return Semantics(
    button: true,
    label: "I'm safe — hold to stop the countdown and cancel the auto-call",
    child: SosCard(
      palette: palette,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: ref.backToTriage,
            child: Container(
              height: SosTokens.touchTap,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(SosTokens.radiusMd),
                border: Border.all(color: palette.safe, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(SosIcons.resolve('i-am-safe'), color: SosStatus.reached),
                  const SizedBox(width: SosTokens.space3),
                  Text("I'm safe", style: SosText.headline(SosStatus.reached)),
                ],
              ),
            ),
          ),
          const SizedBox(height: SosTokens.space3),
          Text(
            'Hold to stop the countdown & cancel auto-call',
            textAlign: TextAlign.center,
            style: SosText.body(palette.textMuted),
          ),
        ],
      ),
    ),
  );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.palette, required this.data});

  final SurfacePalette palette;
  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final name = data['name']?.toString() ?? '';
    final relation = data['relation']?.toString();
    final status = data['status']?.toString();
    final color = SosStatus.forContactStatus(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: SosTokens.space3),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: palette.tray,
            child: Text(
              _initials(name),
              style: SosText.label(palette.textMuted),
            ),
          ),
          const SizedBox(width: SosTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: SosText.title(palette.text)),
                if (relation != null)
                  Text(relation, style: SosText.body(palette.textMuted)),
              ],
            ),
          ),
          Text(
            _statusLabel(status),
            style: SosText.label(color).copyWith(letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 ? parts.last.characters.first : '';
    return '$first$last'.toUpperCase();
  }

  static String _statusLabel(String? status) => switch (status) {
    'reached' => 'Reached',
    'sending' => 'Sending',
    'failed' => 'Failed',
    _ => 'Queued',
  };
}

class _FilledButton extends StatelessWidget {
  const _FilledButton({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SosTokens.touchMin + 12,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(SosTokens.radiusSm),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: SosTokens.fontDisplay,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.palette, required this.label});

  final SurfacePalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SosTokens.touchMin + 12,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(SosTokens.radiusSm),
        border: Border.all(color: palette.textMuted.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: SosText.title(palette.textMuted)),
    );
  }
}
