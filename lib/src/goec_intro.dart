import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'geometry.dart';

/// Go EC launch intro.
///
/// Put it at the root of the first screen: `GoEcIntro(child: HomeScreen())`.
/// [child] is built straight away underneath the intro, so the app can load while the
/// logo plays. At the end the camera flies through the bolt in the logo and the child is
/// revealed through it; then the intro removes itself and [onFinished] is called.
///
/// Phones with reduced motion turned on, or that can't keep up during the first frames,
/// get the static splash (the finished logo) for [staticHold], then fade to the child.
class GoEcIntro extends StatefulWidget {
  const GoEcIntro({
    super.key,
    required this.child,
    this.onFinished,
    this.onFallback,
    this.rollLetters = true,
    this.staticHold = const Duration(milliseconds: 900),
    this.skipOnSlowFrames = true,
  });

  final Widget child;
  final VoidCallback? onFinished;

  /// Called if the still logo is shown instead of the animation, with the reason.
  /// Useful for analytics: how many users get the fallback.
  final ValueChanged<GoEcFallback>? onFallback;

  /// Letters roll like wheels (true) or slide without turning (false).
  final bool rollLetters;

  /// How long the static splash stays up when the animation is skipped.
  final Duration staticHold;

  /// Switch to the static splash when most of the first frames miss the screen's refresh.
  /// Runs in profile and release builds only. Turn off only for screen recordings.
  final bool skipOnSlowFrames;

  /// Tests only: run the slow-phone check in debug builds too.
  @visibleForTesting
  static bool debugCheckFrames = false;

  @override
  State<GoEcIntro> createState() => _GoEcIntroState();
}

/// Why the still logo was shown instead of the animation.
enum GoEcFallback {
  /// Reduce motion / remove animations is on in the phone's settings.
  reducedMotion,

  /// Most of the first frames missed the screen's refresh.
  slowPhone,
}

/// Placeholder for the screen after the intro: black, with one line of text that fades in
/// once the intro has finished. Swap it for the real first screen.
class GoEcIntroPlaceholder extends StatefulWidget {
  const GoEcIntroPlaceholder({super.key, this.text = 'Power of smooth Animations'});

  final String text;

  @override
  State<GoEcIntroPlaceholder> createState() => _GoEcIntroPlaceholderState();
}

class _GoEcIntroPlaceholderState extends State<GoEcIntroPlaceholder> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    // Starts when the intro's dive lands (see _Timeline.end), so the text appears on arrival.
    _wait = Timer(Duration(milliseconds: (_Timeline.end + 60).round()), _fade.forward);
  }

  @override
  void dispose() {
    _wait?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF000000),
      child: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _fade, curve: const Cubic(0, 0, 0.58, 1)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: GoEcColors.white, fontSize: 22, fontWeight: FontWeight.w600, decoration: TextDecoration.none),
            ),
          ),
        ),
      ),
    );
  }
}

/// Every timing in the intro, in ms from launch. The whole thing lands at [end] (3.8 s).
class _Timeline {
  static const ringStart = 0.0, ringDur = 450.0;
  static const plugStart = 280.0, plugDur = 620.0;
  static const letterDur = 600.0;
  static const gStart = 430.0, oStart = 570.0, cStart = 710.0;
  static const eStart = 1240.0, eDur = 900.0;
  static const sparkStart = 2220.0, sparkDur = 900.0; // 80 ms after the e settles
  static const flashAt = 280.0; // into the spark
  static const futureDelay = 70.0; // "Future" lights after "Powering"
  static const diveStart = 2950.0, diveDur = 850.0;
  static const portalOpen = diveStart + diveDur * 0.2; // bolt starts showing the next screen
  static const portalFade = diveDur * 0.12;
  static const end = diveStart + diveDur;
  static const settled = sparkStart + sparkDur; // the finished splash, used for the static fallback
}

/// Arrivals: full speed from the first frame, held until [brakeAt], then a cosine brake
/// to a stop. Speed v0 = 2 / (1 + brakeAt) so the distance comes out to exactly 1.
class _BrakeCurve extends Curve {
  const _BrakeCurve();
  static const brakeAt = 0.55;

  @override
  double transformInternal(double t) {
    const v0 = 2 / (1 + brakeAt);
    if (t <= brakeAt) return v0 * t;
    final u = (t - brakeAt) / (1 - brakeAt);
    return v0 * brakeAt + v0 * (1 - brakeAt) / 2 * (u + math.sin(math.pi * u) / math.pi);
  }
}

const _brake = _BrakeCurve();
const _easeOut = Cubic(0, 0, 0.58, 1);
const _easeInOut = Cubic(0.42, 0, 0.58, 1);
const _plugTravel = Cubic(0.2, 0.75, 0.35, 1);

double _progress(double ms, double start, double dur) => ((ms - start) / dur).clamp(0.0, 1.0);

/// Piecewise-linear lookup in [[ms, value], ...], held flat outside the range.
double _keyed(List<List<double>> kf, double ms) {
  if (ms <= kf.first[0]) return kf.first[1];
  for (var i = 1; i < kf.length; i++) {
    if (ms <= kf[i][0]) {
      final a = kf[i - 1], b = kf[i];
      return a[1] + (b[1] - a[1]) * (ms - a[0]) / (b[0] - a[0]);
    }
  }
  return kf.last[1];
}

// Spark, in ms from the spark's start: two flickers, then the main flash at 280.
const _boltKeys = [[0.0, 0.0], [20.0, 1.0], [50.0, 0.15], [75.0, 0.0], [140.0, 0.85], [165.0, 0.1], [205.0, 0.0], [260.0, 0.0], [280.0, 1.0], [430.0, 1.0], [900.0, 0.0]];
const _glowAlpha = [[0.0, 0.0], [20.0, 0.6], [75.0, 0.0], [140.0, 0.55], [205.0, 0.0], [260.0, 0.0], [280.0, 1.0], [900.0, 0.0]];
const _glowScale = [[0.0, 0.7], [20.0, 0.75], [75.0, 0.75], [140.0, 0.8], [205.0, 0.8], [260.0, 0.8], [280.0, 1.1], [900.0, 1.4]];
const _flashAlpha = [[0.0, 0.0], [265.0, 0.0], [290.0, 1.0], [560.0, 0.0], [900.0, 0.0]];
const _flashScale = [[0.0, 0.6], [265.0, 0.6], [290.0, 1.0], [560.0, 1.15], [900.0, 1.15]];
// Tagline switches on like neon at the main flash.
const _neonKeys = [[0.0, 0.0], [20.0, 1.0], [45.0, 0.15], [75.0, 0.85], [95.0, 0.1], [140.0, 0.0], [165.0, 1.0], [190.0, 0.6], [220.0, 1.0], [320.0, 1.0]];

/// The e: falls from behind the g (accelerating), then swings as a damped pendulum.
/// Fall: Hermite curve from -180 to 0 that starts at rest and ends moving.
/// Settle: A * e^(-kt) * sin(wt), with A*w matched to the fall's end speed so there is no kink.
double _eAngle(double ms) {
  const dur = _Timeline.eDur, fallShare = 0.38, overshoot = 15.0, halfPeriod = 190.0, keep = 0.35;
  const fallMs = dur * fallShare, settleMs = dur - fallMs;
  final w = math.pi / halfPeriod;
  final k = -math.log(keep) / halfPeriod;
  final a = overshoot / math.exp(-k * halfPeriod / 2);
  final m = a * w * fallMs / 180;
  final t = ms.clamp(0.0, dur);
  if (t <= fallMs) {
    final u = t / fallMs;
    final s = (-2 * u * u * u + 3 * u * u) + m * (u * u * u - u * u);
    return -180 + 180 * s;
  }
  final x = t - fallMs;
  return a * math.exp(-k * x) * math.sin(w * x) * (1 - math.pow(x / settleMs, 6));
}

/// Slow-phone check: the gaps between the first [_probeFrames] frames are measured from
/// their vsync timestamps. If the median gap is over [_slowGap] (most frames missing a
/// 60 Hz refresh), the phone gets the static splash. Decided about 0.2 s in.
const _probeFrames = 12;
const _slowGap = Duration(milliseconds: 25);
const _fadeDur = Duration(milliseconds: 250);

class _GoEcIntroState extends State<GoEcIntro> with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _Timeline.end.round()),
  );
  // Static splash: fades in over the last animated frame (slow phone) and fades out to the child.
  late final AnimationController _fadeIn = AnimationController(vsync: this, duration: _fadeDur, value: 1);
  late final AnimationController _fadeOut = AnimationController(vsync: this, duration: _fadeDur);
  final ValueNotifier<double> _clock = ValueNotifier<double>(0);
  final ValueNotifier<double> _frozen = ValueNotifier<double>(0);
  final ValueNotifier<bool> _showChild = ValueNotifier<bool>(false);
  final List<Duration> _gaps = [];
  Duration? _lastFrame;
  bool _done = false;
  bool _static = false;
  bool _started = false;
  Timer? _hold;

  // Debug builds are always slow, so the check only runs in profile and release.
  bool get _checkFrames => widget.skipOnSlowFrames && (!kDebugMode || GoEcIntro.debugCheckFrames);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
    _controller.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _showStatic(GoEcFallback.reducedMotion); // build runs next anyway
    } else {
      _controller.forward();
    }
  }

  void _onTick() {
    final ms = _controller.value * _Timeline.end;
    _clock.value = ms;
    if (ms >= _Timeline.portalOpen) _showChild.value = true;
    if (_checkFrames && _gaps.length < _probeFrames) _measure();
  }

  void _measure() {
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    final last = _lastFrame;
    _lastFrame = now;
    if (last == null) return;
    _gaps.add(now - last);
    if (_gaps.length < _probeFrames) return;
    final sorted = [..._gaps]..sort();
    if (sorted[sorted.length ~/ 2] > _slowGap) setState(() => _showStatic(GoEcFallback.slowPhone, fade: true));
  }

  // Holds the finished logo (no dive) for [GoEcIntro.staticHold], then fades to the child.
  void _showStatic(GoEcFallback reason, {bool fade = false}) {
    _controller.stop();
    // After the frame, so the listener may call setState.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFallback?.call(reason);
    });
    _static = true;
    _frozen.value = _clock.value;
    _clock.value = _Timeline.settled;
    if (fade) _fadeIn.forward(from: 0);
    _hold = Timer(widget.staticHold + (fade ? _fadeDur : Duration.zero), _leaveStatic);
  }

  void _leaveStatic() {
    if (!mounted) return;
    _showChild.value = true;
    _fadeOut.forward().whenCompleteOrCancel(_finish);
  }

  void _finish() {
    if (_done || !mounted) return;
    _showChild.value = true;
    setState(() => _done = true);
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _controller.dispose();
    _fadeIn.dispose();
    _fadeOut.dispose();
    _clock.dispose();
    _frozen.dispose();
    _showChild.dispose();
    super.dispose();
  }

  Widget _paint(ValueListenable<double> clock, {required bool dive}) =>
      CustomPaint(painter: _IntroPainter(clock, roll: widget.rollLetters, dive: dive), size: Size.infinite);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Built and laid out from the start (so it can load), but not painted until the
        // bolt opens: the intro covers it until then.
        ValueListenableBuilder<bool>(
          valueListenable: _showChild,
          child: widget.child,
          builder: (context, show, child) =>
              Visibility(visible: show, maintainState: true, maintainAnimation: true, maintainSize: true, child: child!),
        ),
        if (!_done)
          AbsorbPointer(
            child: FadeTransition(
              opacity: ReverseAnimation(_fadeOut),
              child: RepaintBoundary(
                child: _static
                    ? Stack(fit: StackFit.expand, children: [
                        _paint(_frozen, dive: false),
                        FadeTransition(opacity: _fadeIn, child: _paint(_clock, dive: false)),
                      ])
                    : _paint(_clock, dive: true),
              ),
            ),
          ),
      ],
    );
  }
}

class _IntroPainter extends CustomPainter {
  _IntroPainter(this.clock, {required this.roll, required this.dive}) : super(repaint: clock);

  final ValueListenable<double> clock;
  final bool roll;
  final bool dive;

  static const _g = GoEcGeometry.markCenter;
  static final double _tilt = GoEcGeometry.tiltDeg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = clock.value;
    const box = GoEcGeometry.box;
    final k = size.width * GoEcGeometry.widthShare / box.width; // px per source unit
    final originX = size.width / 2 - box.width * k / 2 - box.left * k;
    final originY = size.height * GoEcGeometry.centerYShare - box.height * k / 2 - box.top * k;
    Offset toScreen(Offset u) => Offset(originX + u.dx * k, originY + u.dy * k);
    Offset markFrame(Offset p) => _g + Offset(p.dx * math.cos(_tilt) - p.dy * math.sin(_tilt), p.dx * math.sin(_tilt) + p.dy * math.cos(_tilt));

    // Camera: base placement, then the dive. One continuous move: the zoom's progress is
    // measured on a log scale (each frame multiplies the scale), f = t^power starts from
    // rest and only ever speeds up, and the drift of the bolt to the screen centre uses the
    // same f, so the camera travels in a straight line into the bolt with no separate
    // alignment step.
    final base = Matrix4.translationValues(originX, originY, 0).multiplied(Matrix4.diagonal3Values(k, k, 1));
    var camera = base;
    if (dive && ms > _Timeline.diveStart) {
      final t = _progress(ms, _Timeline.diveStart, _Timeline.diveDur);
      final focus = toScreen(markFrame(GoEcGeometry.boltCore));
      final end = math.sqrt(size.width * size.width + size.height * size.height) / 2 / (GoEcGeometry.boltCoreRadius * k) * 1.15;
      const power = 1.7;
      final f = math.pow(t, power).toDouble();
      final s = math.pow(end, f).toDouble();
      final dx = (size.width / 2 - focus.dx) * f, dy = (size.height / 2 - focus.dy) * f;
      final zoom = Matrix4.translationValues(focus.dx + dx, focus.dy + dy, 0)
          .multiplied(Matrix4.diagonal3Values(s, s, 1))
          .multiplied(Matrix4.translationValues(-focus.dx, -focus.dy, 0));
      camera = zoom.multiplied(base);
    }
    final markMatrix = Matrix4.translationValues(_g.dx, _g.dy, 0).multiplied(Matrix4.rotationZ(_tilt));

    // Background. Once the portal opens, the bolt is cut out of it so the next screen shows through.
    final full = Offset.zero & size;
    final blue = Paint()..color = GoEcColors.blue;
    final portalOpen = dive && ms >= _Timeline.portalOpen;
    if (portalOpen) {
      final hole = GoEcGeometry.boltShape.transform(camera.multiplied(markMatrix).storage);
      canvas.drawPath(Path()..fillType = PathFillType.evenOdd..addRect(full)..addPath(hole, Offset.zero), blue);
    } else {
      canvas.drawRect(full, blue);
    }

    canvas.save();
    canvas.transform(camera.storage);

    final sparkMs = ms - _Timeline.sparkStart;
    final sparkU = _progress(ms, _Timeline.sparkStart, _Timeline.sparkDur);
    final sparkEased = _easeOut.transform(sparkU) * _Timeline.sparkDur;

    // Glow behind the plug: shines through the bolt cut-out and around the plug.
    final glowA = sparkMs < 0 ? 0.0 : _keyed(_glowAlpha, sparkEased);
    if (glowA > 0) {
      final r = 800 * _keyed(_glowScale, sparkEased);
      _radial(canvas, _g, r, [
        GoEcColors.green.withAlpha((0.9 * glowA * 255).round()),
        GoEcColors.green.withAlpha((0.3 * glowA * 255).round()),
        GoEcColors.green.withAlpha(0),
      ], const [0, 0.45, 1]);
    }

    // Ring turns into place.
    final ringP = _brake.transform(_progress(ms, _Timeline.ringStart, _Timeline.ringDur));
    _inMark(canvas, () {
      canvas.rotate(-120 * math.pi / 180 * (1 - ringP));
      canvas.scale(0.85 + 0.15 * ringP);
      canvas.rotate(_tilt);
      _fill(canvas, GoEcGeometry.ring, GoEcColors.white, ringP);
    });

    // Cord grows from where it leaves the ring; the plug head rides its tip,
    // overshoots by 30 units and seats.
    final plugU = _progress(ms, _Timeline.plugStart, _Timeline.plugDur);
    const over = 1 + 30 / (GoEcGeometry.cordRoot - GoEcGeometry.cordX0);
    final double grow;
    final double plugA;
    if (ms < _Timeline.plugStart) {
      grow = 0;
      plugA = 0;
    } else if (plugU < 0.06) {
      grow = 0.04 * plugU / 0.06;
      plugA = plugU / 0.06;
    } else if (plugU < 0.7) {
      grow = 0.04 + (over - 0.04) * _plugTravel.transform(((plugU - 0.06) / 0.64).clamp(0.0, 1.0));
      plugA = 1;
    } else {
      grow = over + (1 - over) * _easeInOut.transform(((plugU - 0.7) / 0.3).clamp(0.0, 1.0));
      plugA = 1;
    }
    if (plugA > 0) {
      const root = GoEcGeometry.cordRoot, midY = (GoEcGeometry.cordY0 + GoEcGeometry.cordY1) / 2;
      _inMark(canvas, () {
        canvas.rotate(_tilt);
        canvas.save();
        canvas.translate(root, midY);
        canvas.scale(math.max(grow, 0.001), 1);
        canvas.translate(-root, -midY);
        _fill(canvas, GoEcGeometry.cord, GoEcColors.white, plugA);
        canvas.restore();
        canvas.translate((root - GoEcGeometry.cordX0) * (1 - grow), 0);
        _fill(canvas, GoEcGeometry.plug, GoEcColors.white, plugA);
      });
    }

    // Bolt lights green, then (during the dive) a blue cover fades off the cut-out
    // so the next screen appears inside it.
    final boltA = sparkMs < 0 ? 0.0 : _keyed(_boltKeys, sparkMs);
    final coverA = portalOpen ? 1 - ((ms - _Timeline.portalOpen) / _Timeline.portalFade).clamp(0.0, 1.0) : 0.0;
    if (boltA > 0 || coverA > 0) {
      _inMark(canvas, () {
        canvas.rotate(_tilt);
        if (coverA > 0) _fill(canvas, GoEcGeometry.boltShape, GoEcColors.blue, coverA);
        if (boltA > 0) _fill(canvas, GoEcGeometry.boltShape, GoEcColors.green, boltA);
      });
    }

    // The e: mirrored behind the g, flips down on the hinge and swings to rest.
    if (ms >= _Timeline.eStart) {
      final pivot = Offset(GoEcGeometry.letterE.dx, GoEcGeometry.hingeY);
      const persp = 2.4 * 2 * (GoEcGeometry.ringR + 2);
      final flip = Matrix4.translationValues(pivot.dx, pivot.dy, 0)
          .multiplied(Matrix4.identity()..setEntry(3, 2, 1 / persp))
          .multiplied(Matrix4.rotationX(_eAngle(ms - _Timeline.eStart) * math.pi / 180))
          .multiplied(Matrix4.translationValues(-pivot.dx, -pivot.dy, 0));
      canvas.save();
      canvas.transform(flip.storage);
      canvas.translate(GoEcGeometry.letterE.dx, GoEcGeometry.letterE.dy);
      canvas.scale(1, -1);
      _fill(canvas, GoEcGeometry.gLetter, GoEcColors.white, 1);
      canvas.restore();
    }

    // g, o, c roll in from the right: angle = distance / radius, so they roll without slipping.
    void letter(Path path, Offset c, Color color, double start) {
      final p = _brake.transform(_progress(ms, start, _Timeline.letterDur));
      final leftPx = originX + (c.dx - GoEcGeometry.ringR) * k;
      final dx = (size.width - leftPx + 4) / k; // in source units: just off the right edge
      canvas.save();
      canvas.translate(c.dx + dx * (1 - p), c.dy);
      if (roll) canvas.rotate(dx / GoEcGeometry.ringR * (1 - p));
      _fill(canvas, path, color, 1);
      canvas.restore();
    }

    letter(GoEcGeometry.gLetter, GoEcGeometry.letterG, GoEcColors.green, _Timeline.gStart);
    letter(GoEcGeometry.oLetter, GoEcGeometry.letterO, GoEcColors.white, _Timeline.oStart);
    letter(GoEcGeometry.cLetter, GoEcGeometry.letterC, GoEcColors.green, _Timeline.cStart);

    // Tagline flickers on in place with the main flash.
    final neonStart = _Timeline.sparkStart + _Timeline.flashAt;
    final pA = ms < neonStart ? 0.0 : _keyed(_neonKeys, ms - neonStart);
    final fA = ms < neonStart + _Timeline.futureDelay ? 0.0 : _keyed(_neonKeys, ms - neonStart - _Timeline.futureDelay);
    if (pA > 0 || fA > 0) {
      final b = GoEcGeometry.taglineBounds;
      canvas.save();
      canvas.translate(GoEcGeometry.taglineCenterX, GoEcGeometry.taglineTop);
      canvas.scale(GoEcGeometry.taglineScale);
      canvas.translate(-b.center.dx, -b.top);
      _fill(canvas, GoEcGeometry.powering, GoEcColors.white, pA);
      _fill(canvas, GoEcGeometry.future, GoEcColors.white, fA);
      canvas.restore();
    }

    // One wide, faint wash of light over the whole lockup at the main flash.
    final flashA = sparkMs < 0 ? 0.0 : _keyed(_flashAlpha, sparkEased);
    if (flashA > 0) {
      _radial(canvas, _g, 2600 * _keyed(_flashScale, sparkEased), [
        const Color(0xFFC8FFEC).withAlpha((0.5 * flashA * 255).round()),
        GoEcColors.green.withAlpha((0.2 * flashA * 255).round()),
        GoEcColors.green.withAlpha(0),
      ], const [0, 0.35, 0.75]);
    }

    canvas.restore();
  }

  void _inMark(Canvas canvas, VoidCallback draw) {
    canvas.save();
    canvas.translate(_g.dx, _g.dy);
    draw();
    canvas.restore();
  }

  void _fill(Canvas canvas, Path path, Color color, double alpha) {
    if (alpha <= 0) return;
    canvas.drawPath(path, Paint()..color = color.withAlpha((alpha.clamp(0.0, 1.0) * 255).round()));
  }

  void _radial(Canvas canvas, Offset c, double r, List<Color> colors, List<double> stops) {
    canvas.drawCircle(c, r, Paint()..shader = ui.Gradient.radial(c, r, colors, stops));
  }

  @override
  bool shouldRepaint(_IntroPainter old) => old.roll != roll || old.dive != dive || old.clock != clock;
}
