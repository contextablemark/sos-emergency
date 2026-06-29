import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_emergency/application/ai_orchestration.dart';
import 'package:sos_emergency/application/voice_agent_providers.dart';
import 'package:sos_emergency/application/voice_session_controller.dart';
import 'package:sos_emergency/data/voice_session/fake_voice_session.dart';
import 'package:sos_emergency/presentation/surface/surface_host.dart';

import '../golden/golden_harness.dart';

/// Android Automotive head-unit form factor: wide but short. The catalog was
/// designed for taller tablet windows, so this is the breakpoint the responsive
/// scaling exists for.
const Size _aaos = Size(1408, 720);

/// The canonical landscape-tablet breakpoint (tall enough that nothing scales).
const Size _tablet = Size(1194, 834);

Future<ProviderContainer> _pumpHost(
  WidgetTester tester, {
  required Size size,
  FakeVoiceSession? voice,
}) async {
  await loadSosFonts();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      if (voice != null) voiceSessionProvider.overrideWithValue(voice),
    ],
  );
  addTearDown(container.dispose);
  container.read(aiEnabledProvider.notifier).disable();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: SurfaceHost())),
    ),
  );
  return container;
}

void main() {
  group('AAOS 1408×720', () {
    testWidgets('triage fits: no overflow, inline voice card dropped', (
      tester,
    ) async {
      await _pumpHost(tester, size: _aaos);

      // Triage rendered, and nothing overflowed laying it out at 720 dp tall.
      expect(find.text("What's happening?"), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The tall inline PushToTalk card is dropped on the short window…
      expect(find.text('Tap to speak'), findsNothing);
      // …because the always-on rail exposes the voice button instead.
      expect(find.bySemanticsLabel('Voice assistant'), findsOneWidget);
    });

    testWidgets('rail voice button is on-screen and starts the session', (
      tester,
    ) async {
      final fake = FakeVoiceSession();
      final container = await _pumpHost(tester, size: _aaos, voice: fake);

      final voiceButton = find.bySemanticsLabel('Voice assistant');
      expect(voiceButton, findsOneWidget);

      // Fully within the 1408×720 viewport — never scrolls out of view.
      final rect = tester.getRect(voiceButton);
      expect(rect.bottom, lessThanOrEqualTo(_aaos.height));
      expect(rect.right, lessThanOrEqualTo(_aaos.width));
      expect(voiceButton.hitTestable(), findsOneWidget);

      await tester.tap(voiceButton);
      await tester.pumpAndSettle();

      // Tapping the rail control toggles voice on (same action as PushToTalk).
      final status = container.read(voiceSessionControllerProvider).status;
      expect(
        status,
        anyOf(VoiceSessionStatus.connecting, VoiceSessionStatus.live),
      );
    });

    testWidgets('scenario screens compose without overflow', (tester) async {
      await _pumpHost(tester, size: _aaos);

      for (final choice in const ['Crash', 'Being followed']) {
        await tester.tap(find.text(choice));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$choice scenario overflowed at 1408×720',
        );
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
      }
    });
  });

  testWidgets('tablet 1194×834 keeps the inline voice card', (tester) async {
    await _pumpHost(tester, size: _tablet);

    // Tall windows are not compact, so PushToTalk still renders.
    expect(find.text('Tap to speak'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
