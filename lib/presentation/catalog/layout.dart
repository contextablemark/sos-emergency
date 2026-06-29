import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sos_emergency/app/theme/sos_tokens.dart';
import 'package:sos_emergency/app/theme/surface_palette.dart';
import 'package:sos_emergency/domain/models/a2ui_node.dart';
import 'package:sos_emergency/domain/models/severity.dart';
import 'package:sos_emergency/presentation/catalog/shared/sos_chrome.dart';
import 'package:sos_emergency/presentation/catalog/shared/sos_icons.dart';
import 'package:sos_emergency/presentation/surface/a2ui_renderer.dart';
import 'package:sos_emergency/presentation/surface/binding_resolver.dart';
import 'package:sos_emergency/presentation/surface/surface_actions.dart';
import 'package:sos_emergency/presentation/surface/surface_metrics.dart';
import 'package:sos_emergency/presentation/surface/surface_theme_providers.dart';

/// `EmergencyRoot` — the Surface root every screen mounts into. The AI fills
/// the centre; the persistent safety rail (911 + live-location + voice) is part
/// of the root, never the AI's composition, so it can never be omitted.
/// Inputs: `tier`, `theme`, `carState`. Children are the AI-composed surface.
Widget buildEmergencyRoot(BuildContext context, WidgetRef ref, A2uiNode node) {
  final palette = ref.watch(surfacePaletteProvider);
  final metrics = SurfaceMetrics.of(context);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // The AI-composed surface is scrollable; the persistent rail is not.
      Expanded(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < node.children.length; i++) ...[
                if (i > 0) const SizedBox(height: SosTokens.space5),
                A2uiRenderer(node: node.children[i]),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(width: SosTokens.space5),
      SizedBox(
        width: metrics.railWidth,
        child: _SafetyRail(
          palette: palette,
          onCall: ref.callEmergencyNow,
          onShare: ref.toggleLocationSharing,
          onVoice: ref.toggleVoice,
        ),
      ),
    ],
  );
}

class _SafetyRail extends StatelessWidget {
  const _SafetyRail({
    required this.palette,
    required this.onCall,
    required this.onShare,
    required this.onVoice,
  });

  final SurfacePalette palette;
  final VoidCallback onCall;
  final VoidCallback onShare;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('ALWAYS ON', style: SosText.label(palette.textMuted)),
        const SizedBox(height: SosTokens.space3),
        // The 911 square keeps its 1:1 ratio; on a short window the whole rail
        // narrows via `railWidth`, which shrinks this button with it.
        AspectRatio(
          aspectRatio: 1,
          child: _Tappable(
            onTap: onCall,
            radius: SosTokens.radiusMd,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [SosTokens.brandRedLight, SosTokens.brandRedDark],
                ),
                borderRadius: BorderRadius.circular(SosTokens.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: SosTokens.brandRedDark.withValues(alpha: 0.5),
                    blurRadius: 22,
                    spreadRadius: -10,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.call, color: Colors.white, size: 26),
                  Text(
                    '911',
                    style: TextStyle(
                      fontFamily: SosTokens.fontDisplay,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: SosTokens.space3),
        _Tappable(
          onTap: onShare,
          radius: SosTokens.radiusSm,
          child: _RailTile(
            color: palette.safe.withValues(alpha: 0.14),
            border: palette.safe,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StatusDot(color: palette.safe, size: 9),
                const SizedBox(width: SosTokens.space2),
                Text('Live', style: SosText.label(SosStatus.reached)),
              ],
            ),
          ),
        ),
        const SizedBox(height: SosTokens.space3),
        // Always-visible voice entry — the primary voice control on short
        // windows where the inline PushToTalk card is dropped.
        Semantics(
          button: true,
          label: 'Voice assistant',
          child: _Tappable(
            onTap: onVoice,
            radius: SosTokens.radiusSm,
            child: _RailTile(
              color: palette.surface,
              border: palette.textMuted.withValues(alpha: 0.2),
              child: Icon(SosIcons.resolve('voice'), color: palette.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

/// A ripple-on-tap wrapper that respects a corner radius.
class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.onTap,
    required this.radius,
    required this.child,
  });

  final VoidCallback onTap;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.color,
    required this.border,
    required this.child,
  });

  final Color color;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(SosTokens.radiusSm),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

/// `ActionStack` — vertical stack of primary actions ranked by safety.
/// Collapses to a single giant button when `carState=driving`; a short ranked
/// list when parked. Inputs: `actions[]{label,icon,tier}`, `carState`.
Widget buildActionStack(BuildContext context, WidgetRef ref, A2uiNode node) {
  final palette = ref.watch(surfacePaletteProvider);
  final carState = ref.resolveString(node, 'carState') ?? 'parked';
  final actions = (ref.resolve(node, 'actions') as List?) ?? const [];
  if (actions.isEmpty) {
    return SosCard(
      palette: palette,
      child: EmptyState(palette: palette, message: 'No actions available'),
    );
  }

  final parsed = actions
      .map((a) => (a as Map).cast<String, Object?>())
      .toList();

  if (carState == 'driving') {
    return _ActionTile(
      palette: palette,
      data: parsed.first,
      height: SurfaceMetrics.of(context).panicSize,
      emphatic: true,
    );
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < parsed.length; i++) ...[
        if (i > 0) const SizedBox(height: SosTokens.space3),
        _ActionTile(
          palette: palette,
          data: parsed[i],
          height: SosTokens.touchTap,
          emphatic: i == 0,
        ),
      ],
    ],
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.palette,
    required this.data,
    required this.height,
    required this.emphatic,
  });

  final SurfacePalette palette;
  final Map<String, Object?> data;
  final double height;
  final bool emphatic;

  @override
  Widget build(BuildContext context) {
    final label = data['label']?.toString() ?? '';
    final icon = SosIcons.resolve(data['icon']?.toString());
    final tier = Severity.fromToken(data['tier']?.toString());
    final isCritical = tier == Severity.critical || emphatic;
    final fg = isCritical ? Colors.white : palette.text;

    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: SosTokens.space4),
      decoration: BoxDecoration(
        gradient: isCritical
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [SosTokens.brandRedLight, SosTokens.brandRedDark],
              )
            : null,
        color: isCritical ? null : palette.surface,
        borderRadius: BorderRadius.circular(SosTokens.radiusMd),
        border: isCritical
            ? null
            : Border.all(color: palette.textMuted.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: SosTokens.space3),
          Flexible(child: Text(label, style: SosText.headline(fg))),
        ],
      ),
    );
  }
}

/// `SectionCard` — bordered grouping for related instructions or data, with an
/// optional titled header and tier accent edge. Inputs: `title?`, `tier`.
/// Children are nested by the AI.
Widget buildSectionCard(BuildContext context, WidgetRef ref, A2uiNode node) {
  final palette = ref.watch(surfacePaletteProvider);
  final title = ref.resolveString(node, 'title');
  final tier = node.props.containsKey('tier')
      ? Severity.fromToken(ref.resolveString(node, 'tier'))
      : null;

  return SosCard(
    palette: palette,
    tier: tier,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Text(title.toUpperCase(), style: SosText.label(palette.textMuted)),
          const SizedBox(height: SosTokens.space3),
        ],
        for (var i = 0; i < node.children.length; i++) ...[
          if (i > 0) const SizedBox(height: SosTokens.space3),
          A2uiRenderer(node: node.children[i]),
        ],
      ],
    ),
  );
}
