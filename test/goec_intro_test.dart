import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goec_intro/goec_intro.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduceMotion),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );

void main() {
  testWidgets('plays through every phase and hands over to the child', (tester) async {
    var finished = false;
    await tester.pumpWidget(_host(GoEcIntro(onFinished: () => finished = true, child: const GoEcIntroPlaceholder())));

    // Step through the whole timeline so every branch of the painter runs.
    for (var ms = 0; ms <= 3800; ms += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: 'paint failed at $ms ms');
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(finished, isTrue);
    expect(find.byType(CustomPaint), findsNothing, reason: 'intro layer should be gone');

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Power of smooth Animations'), findsOneWidget);
  });

  testWidgets('reduced motion shows the static splash, then the child', (tester) async {
    var finished = false;
    await tester.pumpWidget(_host(
      GoEcIntro(onFinished: () => finished = true, child: const GoEcIntroPlaceholder()),
      reduceMotion: true,
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(finished, isFalse);
    // Hold (900 ms) runs out, then a 250 ms fade to the child.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(finished, isTrue);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a phone that misses frames gets the static splash', (tester) async {
    GoEcIntro.debugCheckFrames = true;
    addTearDown(() => GoEcIntro.debugCheckFrames = false);
    var finished = false;
    await tester.pumpWidget(_host(GoEcIntro(onFinished: () => finished = true, child: const GoEcIntroPlaceholder())));

    // 40 ms frames (25 fps): decided after 12 frames, then fade in, hold, fade out.
    var ms = 0;
    while (!finished && ms < 3000) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.takeException(), isNull);
      ms += 40;
    }
    expect(finished, isTrue);
    // Static path: 12 frames + 250 fade + 900 hold + 250 fade, well before the 3.8 s animation would end.
    expect(ms, lessThan(2000));
  });

  testWidgets('a phone that keeps up plays the full animation', (tester) async {
    GoEcIntro.debugCheckFrames = true;
    addTearDown(() => GoEcIntro.debugCheckFrames = false);
    var finished = false;
    await tester.pumpWidget(_host(GoEcIntro(onFinished: () => finished = true, child: const GoEcIntroPlaceholder())));
    var ms = 0;
    while (!finished && ms < 5000) {
      await tester.pump(const Duration(microseconds: 16667));
      ms += 17;
    }
    expect(ms, greaterThan(3700));
  });
}
