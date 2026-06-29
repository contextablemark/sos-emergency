import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sos_emergency/app/theme/sos_tokens.dart';
import 'package:sos_emergency/app/theme/surface_palette.dart';
import 'package:sos_emergency/application/voice_session_controller.dart';
import 'package:sos_emergency/domain/models/a2ui_node.dart';
import 'package:sos_emergency/presentation/catalog/shared/sos_chrome.dart';
import 'package:sos_emergency/presentation/catalog/shared/sos_icons.dart';
import 'package:sos_emergency/presentation/surface/a2ui_renderer.dart';
import 'package:sos_emergency/presentation/surface/binding_resolver.dart';
import 'package:sos_emergency/presentation/surface/surface_actions.dart';
import 'package:sos_emergency/presentation/surface/surface_metrics.dart';
import 'package:sos_emergency/presentation/surface/surface_theme_providers.dart';

/// `BigChoiceCard` — a large, icon-led, mutually-exclusive choice. One tap
/// selects and advances; no submit step. Inputs: `label`, `icon`, `selected?`,
/// `scenario?` (navigation target).
Widget buildBigChoiceCard(BuildContext context, WidgetRef ref, A2uiNode node) {
  final palette = ref.watch(surfacePaletteProvider);
  final label = ref.resolveString(node, 'label') ?? '';
  final iconName = ref.resolveString(node, 'icon');
  final selected = ref.resolve(node, 'selected') == true;
  final scenario = ref.resolveString(node, 'scenario');
  final tint = _choiceTint(iconName);

  final card = Container(
    constraints: BoxConstraints(
      minHeight: SurfaceMetrics.of(context).choiceMinHeight,
    ),
    padding: const EdgeInsets.all(SosTokens.space5),
    decoration: BoxDecoration(
      gradient: SosShadows.surfaceGradient(palette),
      borderRadius: BorderRadius.circular(SosTokens.radiusLg),
      border: Border.all(
        color: selected
            ? palette.info
            : palette.textMuted.withValues(alpha: 0.12),
        width: selected ? 2 : 1,
      ),
      boxShadow: SosShadows.soft(palette),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: tint.bg,
            borderRadius: BorderRadius.circular(SosTokens.radiusSm),
          ),
          child: Icon(SosIcons.resolve(iconName), color: tint.fg, size: 26),
        ),
        const SizedBox(height: SosTokens.space3),
        Text(label, style: SosText.title(palette.text)),
      ],
    ),
  );

  if (scenario == null) return card;
  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(SosTokens.radiusLg),
    child: InkWell(
      borderRadius: BorderRadius.circular(SosTokens.radiusLg),
      onTap: () => ref.navigateToScenarioNamed(scenario),
      child: card,
    ),
  );
}

/// Category icon tint for a triage choice, matching the design's coloured icon
/// chips (crash → orange, medical → red, threat → blue, else neutral).
({Color bg, Color fg}) _choiceTint(String? icon) => switch (icon) {
  'crash' => (bg: const Color(0xFFFBEDDD), fg: const Color(0xFFE07B3C)),
  'medical' => (bg: const Color(0xFFFBE5E3), fg: const Color(0xFFD6443D)),
  'unsafe' || 'followed' => (
    bg: const Color(0xFFE2ECF7),
    fg: const Color(0xFF3A7BD0),
  ),
  _ => (bg: const Color(0xFFEEF1F4), fg: const Color(0xFF5B6B7A)),
};

/// `ChoiceGrid` — arranges nested `BigChoiceCard`s in a fixed-column grid; the
/// opening "What's happening?" surface. Input: `columns` (default 4).
///
/// On short (automotive) windows a second row would fall below the fold, so the
/// choices render as a single horizontally-scrollable carousel of large cards
/// instead — no vertical scrolling, touch targets stay big.
Widget buildChoiceGrid(BuildContext context, WidgetRef ref, A2uiNode node) {
  final columns = (node.props['columns'] as num?)?.toInt() ?? 4;

  if (SurfaceMetrics.of(context).isCompact) {
    return _ChoiceCarousel(children: node.children);
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      const gap = SosTokens.space3;
      final tileWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in node.children)
            SizedBox(
              width: tileWidth,
              child: A2uiRenderer(node: child),
            ),
        ],
      );
    },
  );
}

/// A single-row, horizontally-scrollable row of choice cards for short
/// (automotive) windows. Cards keep a large fixed footprint so they stay easy
/// to hit; the row scrolls sideways with a peek at the next card as the
/// affordance that more choices exist.
class _ChoiceCarousel extends StatelessWidget {
  const _ChoiceCarousel({required this.children});

  final List<A2uiNode> children;

  static const double _cardWidth = 208;
  static const double _cardHeight = 188;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('triageChoiceCarousel'),
      height: _cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: SosTokens.space3),
        itemBuilder: (context, i) => SizedBox(
          width: _cardWidth,
          child: A2uiRenderer(node: children[i]),
        ),
      ),
    );
  }
}

/// `YesNoLarge` — two half-surface targets for one critical yes/no. Voice-
/// answerable. Inputs: `question`, `yesLabel?`, `noLabel?`, `yesHint?`,
/// `noHint?`.
Widget buildYesNoLarge(BuildContext context, WidgetRef ref, A2uiNode node) {
  final palette = ref.watch(surfacePaletteProvider);
  final question = ref.resolveString(node, 'question') ?? '';
  return SosCard(
    palette: palette,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          question,
          textAlign: TextAlign.center,
          style: SosText.headline(palette.text),
        ),
        const SizedBox(height: SosTokens.space4),
        Row(
          children: [
            Expanded(
              child: _YesNoTile(
                label: ref.resolveString(node, 'yesLabel') ?? 'Yes',
                hint: ref.resolveString(node, 'yesHint'),
                emphatic: true,
                palette: palette,
              ),
            ),
            const SizedBox(width: SosTokens.space3),
            Expanded(
              child: _YesNoTile(
                label: ref.resolveString(node, 'noLabel') ?? 'No',
                hint: ref.resolveString(node, 'noHint'),
                emphatic: false,
                palette: palette,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _YesNoTile extends StatelessWidget {
  const _YesNoTile({
    required this.label,
    required this.hint,
    required this.emphatic,
    required this.palette,
  });

  final String label;
  final String? hint;
  final bool emphatic;
  final SurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    final fg = emphatic ? Colors.white : palette.text;
    return Container(
      height: SurfaceMetrics.of(context).primaryTouch,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: emphatic
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [SosTokens.brandRedLight, SosTokens.brandRedDark],
              )
            : null,
        color: emphatic ? null : palette.surface,
        borderRadius: BorderRadius.circular(SosTokens.radiusMd),
        border: emphatic
            ? null
            : Border.all(color: palette.textMuted.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: SosText.scream(fg).copyWith(fontSize: 34),
          ),
          if (hint != null)
            Text(
              hint!,
              style: SosText.body(emphatic ? Colors.white : palette.textMuted),
            ),
        ],
      ),
    );
  }
}

/// `StepChecklist` — guided steps with strong current-step emphasis; one "hot"
/// step at a time, done steps recede, future steps dim. Works offline.
/// Inputs: `title?`, `steps[]{title,detail,done}`, `currentIndex`.
Widget buildStepChecklist(BuildContext context, WidgetRef ref, A2uiNode node) {
  final palette = ref.watch(surfacePaletteProvider);
  final title = ref.resolveString(node, 'title');
  final currentIndex = ref.resolveInt(node, 'currentIndex') ?? 0;
  final steps = (ref.resolve(node, 'steps') as List?) ?? const [];

  return SosCard(
    palette: palette,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Text(
            '${title.toUpperCase()} · STEP '
            '${currentIndex + 1} OF ${steps.length}',
            style: SosText.label(palette.textMuted),
          ),
          const SizedBox(height: SosTokens.space4),
        ],
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: SosTokens.space3),
          _StepRow(
            palette: palette,
            index: i,
            data: (steps[i] as Map).cast<String, Object?>(),
            isCurrent: i == currentIndex,
          ),
        ],
      ],
    ),
  );
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.palette,
    required this.index,
    required this.data,
    required this.isCurrent,
  });

  final SurfacePalette palette;
  final int index;
  final Map<String, Object?> data;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? '';
    final detail = data['detail']?.toString();
    final done = data['done'] == true;
    const amber = SosTokens.moderate;

    final marker = CircleAvatar(
      radius: 18,
      backgroundColor: done
          ? palette.safe
          : isCurrent
          ? amber
          : palette.surface,
      child: done
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
          : Text(
              '${index + 1}',
              style: SosText.title(
                isCurrent ? Colors.white : palette.textMuted,
              ),
            ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: SosText.title(
            done || !isCurrent ? palette.textMuted : palette.text,
          ).copyWith(decoration: done ? TextDecoration.lineThrough : null),
        ),
        if (detail != null && isCurrent)
          Text(detail, style: SosText.body(palette.textMuted)),
      ],
    );

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        marker,
        const SizedBox(width: SosTokens.space3),
        Expanded(child: content),
      ],
    );

    if (!isCurrent) {
      return Opacity(opacity: done ? 0.6 : 0.45, child: row);
    }
    return Container(
      padding: const EdgeInsets.all(SosTokens.space4),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SosTokens.radiusMd),
        border: Border.all(color: amber, width: 2),
      ),
      child: row,
    );
  }
}

/// `PushToTalk` — prominent voice entry; the primary input while driving. Big
/// mic target, unmistakable listening state, live transcript. Inputs: `state`
/// (idle·listening·processing), `transcript?`.
Widget buildPushToTalk(BuildContext context, WidgetRef ref, A2uiNode node) {
  // On short landscape windows (AAOS) the tall mic card is dropped: the
  // always-on safety rail already exposes a voice button, so showing this one
  // too would push content off-screen.
  if (SurfaceMetrics.of(context).isCompact) return const SizedBox.shrink();

  final palette = ref.watch(surfacePaletteProvider);
  final propState = ref.resolveString(node, 'state') ?? 'idle';
  final transcript = ref.resolveString(node, 'transcript');
  // The live voice session drives the state; the prop is the fallback.
  final voiceStatus = ref.watch(voiceSessionControllerProvider).status;
  final liveTranscript = ref.watch(voiceSessionControllerProvider).transcript;
  final listening =
      voiceStatus == VoiceSessionStatus.live ||
      voiceStatus == VoiceSessionStatus.connecting ||
      propState == 'listening';

  final body = Container(
    padding: const EdgeInsets.all(SosTokens.space5),
    decoration: BoxDecoration(
      color: listening ? palette.safe.withValues(alpha: 0.12) : palette.tray,
      borderRadius: BorderRadius.circular(SosTokens.radiusMd),
      border: listening ? Border.all(color: palette.safe) : null,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: palette.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: listening
                  ? palette.safe
                  : palette.textMuted.withValues(alpha: 0.2),
              width: listening ? 2 : 1,
            ),
          ),
          child: Icon(
            SosIcons.resolve('voice'),
            size: 44,
            color: listening ? palette.safe : palette.textMuted,
          ),
        ),
        const SizedBox(height: SosTokens.space4),
        if (listening)
          Text(
            liveTranscript ?? transcript ?? 'Listening…',
            textAlign: TextAlign.center,
            style: SosText.body(SosStatus.reached),
          )
        else
          Column(
            children: [
              Text('Tap to speak', style: SosText.headline(palette.text)),
              const SizedBox(height: SosTokens.space1),
              Text(
                'or say "Hey, emergency"',
                style: SosText.body(palette.textMuted),
              ),
            ],
          ),
      ],
    ),
  );

  return Semantics(
    button: true,
    label: listening ? 'Listening — tap to stop' : 'Tap to speak',
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(SosTokens.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(SosTokens.radiusMd),
        onTap: ref.toggleVoice,
        child: body,
      ),
    ),
  );
}
