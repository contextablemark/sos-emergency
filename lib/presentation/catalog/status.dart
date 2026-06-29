import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sos_emergency/app/theme/sos_tokens.dart';
import 'package:sos_emergency/app/theme/surface_palette.dart';
import 'package:sos_emergency/domain/models/a2ui_node.dart';
import 'package:sos_emergency/domain/models/severity.dart';
import 'package:sos_emergency/presentation/catalog/shared/sos_chrome.dart';
import 'package:sos_emergency/presentation/catalog/shared/sos_icons.dart';
import 'package:sos_emergency/presentation/surface/binding_resolver.dart';
import 'package:sos_emergency/presentation/surface/surface_metrics.dart';
import 'package:sos_emergency/presentation/surface/surface_theme_providers.dart';

/// `GuidanceCallout` — the single most important instruction, AI imperative
/// voice, scream type. One on screen at a time. Inputs: `text`, `tier`,
/// `kicker?`.
Widget buildGuidanceCallout(
  BuildContext context,
  WidgetRef ref,
  A2uiNode node,
) {
  final palette = ref.watch(surfacePaletteProvider);
  final tier = Severity.fromToken(ref.resolveString(node, 'tier'));
  final text = ref.resolveString(node, 'text') ?? '';
  final kicker = ref.resolveString(node, 'kicker');

  if (tier == Severity.critical) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SosTokens.space5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEC5751), Color(0xFFD5413B)],
        ),
        borderRadius: BorderRadius.circular(SosTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (kicker ?? 'Do this now').toUpperCase(),
            style: SosText.label(Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: SosTokens.space3),
          Text(text.toUpperCase(), style: SosText.scream(Colors.white)),
        ],
      ),
    );
  }

  return SosCard(
    palette: palette,
    tier: tier == Severity.neutral ? Severity.moderate : tier,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          (kicker ?? 'Tip').toUpperCase(),
          style: SosText.label(TierStyle.of(tier, palette).text),
        ),
        const SizedBox(height: SosTokens.space2),
        Text(text, style: SosText.headline(palette.text)),
      ],
    ),
  );
}

/// `LocationCard` — address + mono coordinates with live share status; the line
/// a dispatcher needs read aloud. Inputs: `address`, `coords`, `accuracy?`,
/// `isSharing`.
Widget buildLocationCard(BuildContext context, WidgetRef ref, A2uiNode node) {
  final palette = ref.watch(surfacePaletteProvider);
  final address = ref.resolveString(node, 'address');
  final coords = ref.resolveString(node, 'coords');
  final detail = ref.resolveString(node, 'detail');
  final isSharing = ref.resolve(node, 'isSharing') == true;

  if (address == null && coords == null) {
    return SosCard(
      palette: palette,
      child: EmptyState(palette: palette, message: 'Acquiring GPS lock…'),
    );
  }

  return SosCard(
    palette: palette,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(SosIcons.resolve('location'), color: palette.safe, size: 20),
            const SizedBox(width: SosTokens.space2),
            Text(
              isSharing ? 'SHARING' : 'LOCATION',
              style: SosText.label(
                isSharing ? SosStatus.reached : palette.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: SosTokens.space3),
        if (address != null) Text(address, style: SosText.title(palette.text)),
        if (detail != null)
          Text(detail, style: SosText.body(palette.textMuted)),
        if (coords != null) ...[
          const SizedBox(height: SosTokens.space3),
          Text(coords, style: SosText.telemetry(palette.info)),
        ],
      ],
    ),
  );
}

/// `CountdownCard` — crash auto-escalation ring counting down to an automatic
/// 911 call. Always paired with a hold-to-abort. Inputs: `secondsLeft`,
/// `totalSeconds`, `message?`.
Widget buildCountdownCard(BuildContext context, WidgetRef ref, A2uiNode node) {
  final palette = ref.watch(surfacePaletteProvider);
  final secondsLeft = ref.resolveInt(node, 'secondsLeft') ?? 0;
  final total = ref.resolveInt(node, 'totalSeconds') ?? 10;
  final message =
      ref.resolveString(node, 'message') ?? 'Calling 911 automatically';
  final progress = total == 0 ? 0.0 : secondsLeft / total;
  final ringSize = SurfaceMetrics.of(context).countdownCircle;

  return SosCard(
    palette: palette,
    child: Row(
      children: [
        SizedBox(
          width: ringSize,
          height: ringSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 10,
                  backgroundColor: SosTokens.critical.withValues(alpha: 0.18),
                  valueColor: const AlwaysStoppedAnimation(SosTokens.critical),
                ),
              ),
              Text(
                secondsLeft.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontFamily: SosTokens.fontDisplay,
                  fontSize: 46,
                  fontWeight: FontWeight.w800,
                  color: SosTokens.criticalText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: SosTokens.space5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: SosText.headline(palette.text)),
              const SizedBox(height: SosTokens.space2),
              Text(
                'Crash detected. Hold "I\'m safe" to stop.',
                style: SosText.body(palette.textMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// `ContactStatusList` — read-only roster of trusted contacts and whether each
/// has been reached. Inputs: `contacts[]{name,relation,status,reachedAt?}`.
Widget buildContactStatusList(
  BuildContext context,
  WidgetRef ref,
  A2uiNode node,
) {
  final palette = ref.watch(surfacePaletteProvider);
  final contacts = (ref.resolve(node, 'contacts') as List?) ?? const [];
  if (contacts.isEmpty) {
    return SosCard(
      palette: palette,
      child: EmptyState(palette: palette, message: 'No contacts to show'),
    );
  }

  return SosCard(
    palette: palette,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final raw in contacts)
          _RosterRow(
            palette: palette,
            data: (raw as Map).cast<String, Object?>(),
          ),
      ],
    ),
  );
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.palette, required this.data});

  final SurfacePalette palette;
  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final name = data['name']?.toString() ?? '';
    final relation = data['relation']?.toString();
    final status = data['status']?.toString();
    final reachedAt = data['reachedAt']?.toString();
    final color = SosStatus.forContactStatus(status);
    final label = switch (status) {
      'reached' => reachedAt == null ? 'Reached' : 'Reached · $reachedAt',
      'sending' => 'Calling…',
      'failed' => 'Failed',
      _ => 'Queued',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SosTokens.space3),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: palette.tray,
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: SosText.title(palette.textMuted),
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
          Text(label, style: SosText.label(color).copyWith(letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

/// `VehicleStatusCard` — relevant vehicle telemetry, shown only when useful to
/// the scenario. Inputs: `metrics[]{label,value,tier?,detail?}`, `profile?`.
Widget buildVehicleStatusCard(
  BuildContext context,
  WidgetRef ref,
  A2uiNode node,
) {
  final palette = ref.watch(surfacePaletteProvider);
  final metrics = (ref.resolve(node, 'metrics') as List?) ?? const [];
  final profile = ref.resolveString(node, 'profile');

  return SosCard(
    palette: palette,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: SosTokens.space3,
          runSpacing: SosTokens.space3,
          children: [
            for (final raw in metrics)
              _MetricTile(
                palette: palette,
                data: (raw as Map).cast<String, Object?>(),
              ),
          ],
        ),
        if (profile != null) ...[
          const SizedBox(height: SosTokens.space3),
          Row(
            children: [
              Icon(
                SosIcons.resolve('vehicle'),
                color: palette.textMuted,
                size: 20,
              ),
              const SizedBox(width: SosTokens.space2),
              Expanded(child: Text(profile, style: SosText.body(palette.text))),
            ],
          ),
        ],
      ],
    ),
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.palette, required this.data});

  final SurfacePalette palette;
  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final label = data['label']?.toString() ?? '';
    final value = data['value']?.toString() ?? '';
    final detail = data['detail']?.toString();
    final tier = Severity.fromToken(data['tier']?.toString());
    final color = tier == Severity.neutral
        ? palette.text
        : TierStyle.of(tier, palette).text;
    return Container(
      width: 180,
      padding: const EdgeInsets.all(SosTokens.space4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(SosTokens.radiusSm),
        border: Border.all(color: palette.textMuted.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: SosText.label(palette.textMuted)),
          const SizedBox(height: SosTokens.space2),
          Text(value, style: SosText.telemetry(color)),
          if (detail != null)
            Text(detail, style: SosText.body(palette.textMuted)),
        ],
      ),
    );
  }
}
