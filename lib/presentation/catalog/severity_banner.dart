import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sos_emergency/app/theme/sos_tokens.dart';
import 'package:sos_emergency/app/theme/surface_palette.dart';
import 'package:sos_emergency/domain/models/a2ui_node.dart';
import 'package:sos_emergency/domain/models/severity.dart';
import 'package:sos_emergency/presentation/catalog/shared/sos_chrome.dart';
import 'package:sos_emergency/presentation/surface/binding_resolver.dart';
import 'package:sos_emergency/presentation/surface/surface_metrics.dart';
import 'package:sos_emergency/presentation/surface/surface_theme_providers.dart';

/// `SeverityBanner` — the tier indicator pinned to the top of the surface.
/// Conveys severity by colour + label + glyph + border weight together (the
/// four redundant cues). Inputs: `tier`, `label`, `context?`.
Widget buildSeverityBanner(BuildContext context, WidgetRef ref, A2uiNode node) {
  final palette = ref.watch(surfacePaletteProvider);
  final tier = Severity.fromToken(ref.resolveString(node, 'tier'));
  final style = TierStyle.of(tier, palette);
  final label = ref.resolveString(node, 'label') ?? '';
  final statusContext = ref.resolveString(node, 'context');

  return Container(
    height: SurfaceMetrics.of(context).severityHeight,
    padding: const EdgeInsets.symmetric(horizontal: SosTokens.space5),
    decoration: BoxDecoration(
      color: style.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(SosTokens.radiusMd),
      border: Border.all(color: style.accent, width: style.borderWidth),
    ),
    child: Row(
      children: [
        Icon(_glyphFor(tier), color: style.accent, size: 26),
        const SizedBox(width: SosTokens.space3),
        Text(
          label,
          style: const TextStyle(
            fontFamily: SosTokens.fontDisplay,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ).copyWith(color: style.text),
        ),
        const Spacer(),
        if (statusContext != null)
          Text(statusContext, style: SosText.body(palette.textMuted)),
      ],
    ),
  );
}

/// Per-tier glyph — part of the redundant severity signal (never colour alone).
IconData _glyphFor(Severity tier) => switch (tier) {
  Severity.moderate => Icons.info_outline,
  Severity.high => Icons.warning_amber_rounded,
  Severity.critical => Icons.dangerous_outlined,
  Severity.neutral => Icons.circle_outlined,
};
