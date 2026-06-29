import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genui/genui.dart';
import 'package:sos_emergency/app/theme/sos_tokens.dart';
import 'package:sos_emergency/application/voice_emergency_session.dart';
import 'package:sos_emergency/application/voice_session_controller.dart';

/// Renders the latest voice-triggered GenUI surface above the deterministic
/// dashboard when the backend agent calls `render_emergency_ui`.
class VoiceRenderOverlay extends ConsumerWidget {
  const VoiceRenderOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceSessionControllerProvider);
    final surfaceId = voice.voiceSurfaceId;
    final error = voice.voiceError;
    // Show the overlay for a rendered surface OR a render failure — failures
    // must be visible so a "spoke but rendered nothing" turn isn't silent.
    if (surfaceId == null && error == null) return const SizedBox.shrink();

    final session = ref.watch(voiceEmergencySessionProvider);
    final isError = surfaceId == null && error != null;
    // Cap the sheet to a fraction of the window so it never swallows a short
    // landscape screen (e.g. AAOS 720 dp, where a fixed 360 dp covered half).
    final overlayHeight = (MediaQuery.sizeOf(context).height * 0.6).clamp(
      240.0,
      360.0,
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        elevation: 12,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SosTokens.radiusLg),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: overlayHeight,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isError
                            ? 'Voice guidance unavailable'
                            : voice.isRendering
                            ? 'Composing guidance…'
                            : 'Voice guidance',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      onPressed: () => ref
                          .read(voiceSessionControllerProvider.notifier)
                          .clearVoiceSurface(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: isError
                      ? _VoiceRenderError(message: error)
                      : Surface(
                          surfaceContext: session.controller.contextFor(
                            surfaceId!,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when a voice-triggered render fails (gated/reasoning/empty model,
/// invalid JSON, transport error) so the user isn't left with silence.
class _VoiceRenderError extends StatelessWidget {
  const _VoiceRenderError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Couldn't show on-screen guidance.",
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(message, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
