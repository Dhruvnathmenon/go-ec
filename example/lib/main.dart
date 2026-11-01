import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:goec_intro/goec_intro.dart';

void main() => runApp(const IntroDemo());

/// Plays the intro into a still of the maps page (the app's first screen), then shows
/// which version played and how smoothly. Tap anywhere to replay.
class IntroDemo extends StatefulWidget {
  const IntroDemo({super.key});

  @override
  State<IntroDemo> createState() => _IntroDemoState();
}

class _IntroDemoState extends State<IntroDemo> with SingleTickerProviderStateMixin {
  int _run = 0;

  // Frame pacing during the intro, from vsync timestamps.
  late final Ticker _ticker = createTicker(_onFrame);
  Duration? _last;
  int _frames = 0, _late = 0;
  Duration _span = Duration.zero;
  GoEcFallback? _fallback;
  String? _result;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onFrame(Duration elapsed) {
    final last = _last;
    _last = elapsed;
    if (last == null) return;
    _frames++;
    _span = elapsed;
    if (elapsed - last > const Duration(milliseconds: 25)) _late++;
  }

  void _onFinished() {
    _ticker.stop();
    final secs = _span.inMicroseconds / 1e6;
    final fps = secs > 0 ? (_frames / secs).round() : 0;
    setState(() {
      _result = switch (_fallback) {
        null => 'Full animation\n$fps fps average, $_late of $_frames frames late',
        GoEcFallback.slowPhone => 'Still logo\nThis phone was too slow for the animation',
        GoEcFallback.reducedMotion => 'Still logo\nRemove animations is on in settings',
      };
    });
  }

  void _replay() {
    setState(() {
      _run++;
      _last = null;
      _frames = 0;
      _late = 0;
      _span = Duration.zero;
      _fallback = null;
      _result = null;
    });
    _ticker
      ..stop()
      ..start();
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: GoEcColors.blue,
      title: 'Go EC intro',
      debugShowCheckedModeBanner: false,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, __) => builder(context)),
      home: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _replay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GoEcIntro(
              key: ValueKey(_run),
              onFinished: _onFinished,
              onFallback: (reason) => _fallback = reason,
              child: Image.asset('assets/maps_placeholder.png', fit: BoxFit.cover, filterQuality: FilterQuality.medium),
            ),
            if (_result != null) _ResultCard(text: _result!),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xF0101418),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GoEcColors.green, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Text(
              '$text\nTap anywhere to replay',
              textAlign: TextAlign.center,
              style: const TextStyle(color: GoEcColors.white, fontSize: 15, height: 1.45, decoration: TextDecoration.none),
            ),
          ),
        ),
      ),
    );
  }
}
