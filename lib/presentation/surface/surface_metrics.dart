import 'package:flutter/widgets.dart';
import 'package:sos_emergency/app/theme/sos_tokens.dart';

/// The canonical landscape-tablet window height the catalog was designed and
/// golden-tested against. At or above this the Surface renders at full density
/// (`heightScale == 1.0`); shorter windows scale down proportionally.
const double kCanonicalWindowHeight = 834;

/// Windows shorter than this are treated as "compact" (e.g. an Android
/// Automotive head unit at 1408×720). Sits between the AAOS height (720) and
/// the shortest tablet breakpoint (834) so the two never collide.
const double kCompactWindowHeight = 768;

/// Viewport-derived sizing for the Surface. Computed once in `SurfaceHost` from
/// the available content height and read by catalog widgets via
/// [SurfaceMetrics.of], so a short landscape window (AAOS) shrinks fixed
/// dimensions instead of clipping them.
///
/// When no [SurfaceMetricsScope] ancestor is present (e.g. golden/widget tests
/// that mount a node directly), [of] returns [fallback] — full density — so the
/// canonical breakpoint renders byte-for-byte as before.
@immutable
class SurfaceMetrics {
  const SurfaceMetrics({required this.heightScale, required this.isCompact});

  /// Builds metrics from the [windowHeight] (dp). Scale is clamped so it never
  /// exceeds full density and never collapses below a legible floor.
  factory SurfaceMetrics.forWindowHeight(double windowHeight) {
    final scale = (windowHeight / kCanonicalWindowHeight).clamp(0.62, 1.0);
    return SurfaceMetrics(
      heightScale: scale,
      isCompact: windowHeight < kCompactWindowHeight,
    );
  }

  /// 1.0 at the canonical height, lower on short screens.
  final double heightScale;

  /// True when the window is shorter than the canonical breakpoint (e.g. AAOS
  /// 720 dp). Drives layout that drops, rather than shrinks, on short screens —
  /// e.g. the triage `PushToTalk` card, since the always-on rail already has a
  /// voice button.
  final bool isCompact;

  // Each getter scales the catalog's design value and clamps to a readable /
  // tappable floor so nothing shrinks past usability.
  double get panicSize => _scaled(SosTokens.touchPanic, 150);
  double get choiceMinHeight => _scaled(150, 104);
  double get severityHeight => _scaled(62, 48);
  double get countdownCircle => _scaled(128, 88);
  double get mapHeight => _scaled(160, 104);
  double get primaryTouch => _scaled(SosTokens.touchPrimary, 96);
  double get railWidth => _scaled(150, 124);

  /// Scales [design] by [heightScale], never below [floor] nor above [design].
  double _scaled(double design, double floor) =>
      (design * heightScale).clamp(floor, design);

  /// Full-density metrics used when no scope is in the tree.
  static const SurfaceMetrics fallback = SurfaceMetrics(
    heightScale: 1,
    isCompact: false,
  );

  /// The metrics provided by the nearest [SurfaceMetricsScope], or [fallback].
  static SurfaceMetrics of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SurfaceMetricsScope>()
          ?.metrics ??
      fallback;

  @override
  bool operator ==(Object other) =>
      other is SurfaceMetrics &&
      other.heightScale == heightScale &&
      other.isCompact == isCompact;

  @override
  int get hashCode => Object.hash(heightScale, isCompact);
}

/// Provides [SurfaceMetrics] to the catalog subtree. Established once per
/// layout pass by `SurfaceHost`.
class SurfaceMetricsScope extends InheritedWidget {
  const SurfaceMetricsScope({
    required this.metrics,
    required super.child,
    super.key,
  });

  final SurfaceMetrics metrics;

  @override
  bool updateShouldNotify(SurfaceMetricsScope oldWidget) =>
      oldWidget.metrics != metrics;
}
