import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sos_emergency/app/theme/sos_tokens.dart';
import 'package:sos_emergency/application/orchestrator.dart';
import 'package:sos_emergency/domain/models/emergency_enums.dart';
import 'package:sos_emergency/domain/models/surface_brightness.dart';
import 'package:sos_emergency/presentation/surface/a2ui_renderer.dart';
import 'package:sos_emergency/presentation/surface/surface_actions.dart';
import 'package:sos_emergency/presentation/surface/surface_metrics.dart';
import 'package:sos_emergency/presentation/surface/surface_theme_providers.dart';
import 'package:sos_emergency/presentation/surface/voice_render_overlay.dart';

/// Hosts the renderer: paints the themed ground and renders the Surface the
/// orchestrator composes for the current scenario. A slim top bar offers a
/// back-to-triage affordance (on scenario screens) and a day/night toggle.
class SurfaceHost extends ConsumerWidget {
  const SurfaceHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(surfacePaletteProvider);
    final surface = ref.watch(surfaceControllerProvider);

    return ColoredBox(
      color: palette.ground,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const _TopBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SosTokens.space12,
                      SosTokens.space4,
                      SosTokens.space12,
                      SosTokens.space12,
                    ),
                    // Expose window-derived sizing so the catalog can adapt to
                    // short landscape windows (e.g. AAOS 1408×720) instead of
                    // clipping fixed components. The window height is exact and
                    // cleanly separates AAOS (720) from tablet (834+).
                    child: SurfaceMetricsScope(
                      metrics: SurfaceMetrics.forWindowHeight(
                        MediaQuery.sizeOf(context).height,
                      ),
                      child: A2uiRenderer(node: surface.root),
                    ),
                  ),
                ),
              ],
            ),
            const VoiceRenderOverlay(),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(surfacePaletteProvider);
    final scenario = ref.watch(demoScenarioProvider);
    final isDay =
        ref.watch(surfaceBrightnessControllerProvider) == SurfaceBrightness.day;
    final onTriage = scenario == ScenarioClass.unknown;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SosTokens.space12,
        SosTokens.space4,
        SosTokens.space12,
        0,
      ),
      child: Row(
        children: [
          if (!onTriage)
            TextButton.icon(
              onPressed: ref.backToTriage,
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              label: const Text('Back'),
              style: TextButton.styleFrom(foregroundColor: palette.textMuted),
            ),
          const Spacer(),
          IconButton(
            tooltip: isDay ? 'Night' : 'Day',
            color: palette.textMuted,
            onPressed: () =>
                ref.read(surfaceBrightnessControllerProvider.notifier).toggle(),
            icon: Icon(
              isDay ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            ),
          ),
        ],
      ),
    );
  }
}
