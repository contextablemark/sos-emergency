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

/// `SafeRouteMap` — a map layer that only ever routes to safety (police, fire,
/// hospital, public place). In threat mode it hides "home" and private
/// destinations. Inputs: `destinations[]{type,name,distance,detail?}`,
/// `threatMode`, `etaLabel?`. (Phase 1 renders a schematic, not a live tile.)
Widget buildSafeRouteMap(BuildContext context, WidgetRef ref, A2uiNode node) {
  final palette = ref.watch(surfacePaletteProvider);
  final threatMode = ref.resolve(node, 'threatMode') == true;
  final etaLabel = ref.resolveString(node, 'etaLabel');
  final destinations = (ref.resolve(node, 'destinations') as List?) ?? const [];

  return SosCard(
    palette: palette,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: SurfaceMetrics.of(context).mapHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.tray,
            borderRadius: BorderRadius.circular(SosTokens.radiusMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(SosIcons.resolve('safe-route'), color: palette.safe),
              const SizedBox(width: SosTokens.space2),
              Text(
                'Routing to safety — not home',
                style: SosText.title(palette.text),
              ),
              if (etaLabel != null) ...[
                const SizedBox(width: SosTokens.space3),
                Text(etaLabel, style: SosText.title(SosStatus.reached)),
              ],
            ],
          ),
        ),
        const SizedBox(height: SosTokens.space3),
        for (final raw in destinations)
          _DestinationRow(
            palette: palette,
            data: (raw as Map).cast<String, Object?>(),
          ),
        if (threatMode) ...[
          const SizedBox(height: SosTokens.space2),
          Container(
            padding: const EdgeInsets.all(SosTokens.space3),
            decoration: BoxDecoration(
              color: SosTokens.critical.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(SosTokens.radiusSm),
              border: Border.all(
                color: SosTokens.critical.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.home_outlined,
                  color: SosTokens.criticalText,
                  size: 18,
                ),
                const SizedBox(width: SosTokens.space2),
                Expanded(
                  child: Text(
                    '"Home" & saved private places hidden '
                    'while threat is active',
                    style: SosText.body(SosTokens.criticalText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({required this.palette, required this.data});

  final SurfacePalette palette;
  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final type = data['type']?.toString();
    final name = data['name']?.toString() ?? '';
    final detail = data['detail']?.toString();
    final distance = data['distance']?.toString();
    final primary = data['primary'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: SosTokens.space2),
      padding: const EdgeInsets.all(SosTokens.space3),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(SosTokens.radiusMd),
        border: Border.all(
          color: primary
              ? palette.safe
              : palette.textMuted.withValues(alpha: 0.16),
          width: primary ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(SosIcons.resolve(type), color: palette.safe, size: 22),
          const SizedBox(width: SosTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: SosText.title(palette.text)),
                if (detail != null)
                  Text(detail, style: SosText.body(palette.textMuted)),
              ],
            ),
          ),
          if (distance != null)
            Text(
              distance,
              style: SosText.label(palette.textMuted).copyWith(fontSize: 15),
            ),
        ],
      ),
    );
  }
}

/// `ETACard` — tracks an inbound responder or roadside truck. Inputs:
/// `provider`, `etaMinutes`, `progress` (0..1), `distance?`, `driver?`.
Widget buildEtaCard(BuildContext context, WidgetRef ref, A2uiNode node) {
  final palette = ref.watch(surfacePaletteProvider);
  final provider = ref.resolveString(node, 'provider');
  if (provider == null) {
    return SosCard(
      palette: palette,
      child: EmptyState(palette: palette, message: 'Dispatching…'),
    );
  }
  final etaMinutes = ref.resolveInt(node, 'etaMinutes') ?? 0;
  final progress = (ref.resolve(node, 'progress') as num?)?.toDouble() ?? 0;
  final distance = ref.resolveString(node, 'distance');
  final driver = ref.resolveString(node, 'driver');

  return SosCard(
    palette: palette,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(SosIcons.resolve('vehicle'), color: SosTokens.moderateText),
            const SizedBox(width: SosTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider, style: SosText.title(palette.text)),
                  if (driver != null)
                    Text(driver, style: SosText.body(palette.textMuted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: SosTokens.space3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$etaMinutes',
              style: SosText.telemetry(palette.safe).copyWith(fontSize: 44),
            ),
            const SizedBox(width: SosTokens.space2),
            Text('min away', style: SosText.title(palette.textMuted)),
          ],
        ),
        const SizedBox(height: SosTokens.space3),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 9,
            backgroundColor: palette.tray,
            valueColor: AlwaysStoppedAnimation(palette.safe),
          ),
        ),
        if (distance != null) ...[
          const SizedBox(height: SosTokens.space2),
          Text(distance, style: SosText.body(palette.textMuted)),
        ],
      ],
    ),
  );
}

/// `WeatherHazardCard` — weather / road-hazard context carrying its own tier so
/// a hazard can raise urgency on its own. Inputs: `condition`, `tier`,
/// `advice?`, `metrics?` (list of strings), `cachedAt?`.
Widget buildWeatherHazardCard(
  BuildContext context,
  WidgetRef ref,
  A2uiNode node,
) {
  final palette = ref.watch(surfacePaletteProvider);
  final condition = ref.resolveString(node, 'condition');
  if (condition == null) {
    return SosCard(
      palette: palette,
      child: EmptyState(palette: palette, message: 'No active hazards'),
    );
  }
  final tier = Severity.fromToken(ref.resolveString(node, 'tier'));
  final advice = ref.resolveString(node, 'advice');
  final cachedAt = ref.resolveString(node, 'cachedAt');
  final metrics = (ref.resolve(node, 'metrics') as List?) ?? const [];
  final style = TierStyle.of(tier, palette);

  return SosCard(
    palette: palette,
    tier: tier == Severity.neutral ? null : tier,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(SosIcons.resolve('weather'), color: style.accent),
            const SizedBox(width: SosTokens.space2),
            Text(
              '${_tierLabel(tier)} · ROAD HAZARD',
              style: SosText.label(style.text),
            ),
          ],
        ),
        const SizedBox(height: SosTokens.space2),
        Text(condition, style: SosText.headline(palette.text)),
        if (advice != null) ...[
          const SizedBox(height: SosTokens.space2),
          Text(advice, style: SosText.body(palette.textMuted)),
        ],
        if (metrics.isNotEmpty) ...[
          const SizedBox(height: SosTokens.space3),
          Wrap(
            spacing: SosTokens.space4,
            children: [
              for (final m in metrics)
                Text(m.toString(), style: SosText.label(palette.textMuted)),
            ],
          ),
        ],
        if (cachedAt != null) ...[
          const SizedBox(height: SosTokens.space2),
          Row(
            children: [
              Icon(
                SosIcons.resolve('offline'),
                color: palette.textMuted,
                size: 16,
              ),
              const SizedBox(width: SosTokens.space2),
              Text(
                'Cached · $cachedAt',
                style: SosText.body(palette.textMuted),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

String _tierLabel(Severity tier) => switch (tier) {
  Severity.moderate => 'MODERATE',
  Severity.high => 'HIGH',
  Severity.critical => 'CRITICAL',
  Severity.neutral => 'INFO',
};
