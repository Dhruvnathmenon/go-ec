# goec_intro

The Go EC launch animation as one Flutter widget. The logo builds itself, the bolt sparks, and the camera flies through the bolt into the app's first screen. Runs 3.8 s.

No images, fonts or packages: the logo is drawn from shapes in code. Flutter 3.10 or newer.

## Add it to the app

**1. Copy the folder** into the repo, for example `packages/goec_intro`, and add it to `pubspec.yaml`:

```yaml
dependencies:
  goec_intro:
    path: packages/goec_intro
```

**2. Wrap the first screen.** `child` is the screen the camera flies into (in Go EC that is the maps screen):

```dart
import 'package:goec_intro/goec_intro.dart';

MaterialApp(
  home: GoEcIntro(
    child: const MapsScreen(),
    onFinished: () {
      // Intro is gone and the maps screen is live.
    },
  ),
);
```

That is the whole integration. What happens to `child`:

- It is built straight away, under the intro, so the map can start loading while the logo plays.
- It is not drawn until the bolt opens (about 3.1 s), then appears inside the bolt and fills the screen.
- Touches are blocked until the intro ends. After that the intro removes itself and `child` keeps its state, so there is no route change and nothing to pop.

**3. Keep the first screen quiet during the intro.** Anything that pops up over the animation breaks it. Move these into `onFinished` or later:

- location permission prompts and other dialogs
- snackbars, toasts, onboarding sheets

Loading data and map tiles in the background is fine.

**4. Make the native launch screen plain blue `#003DBA`**, the intro's first colour, so launch goes native splash, then intro, with no flash:

- Android: `android/app/src/main/res/drawable/launch_background.xml` (and `drawable-v21`). On Android 12+ also set `android:windowSplashScreenBackground` to `#003DBA` in `values-v31/styles.xml`. Android 12+ always shows the app icon on its splash; that is the system's, not ours.
- iOS: `ios/Runner/Base.lproj/LaunchScreen.storyboard`, background `#003DBA`, no logo.

The Android side is already done in `example/android/app/src/main/res` (`drawable*/launch_background.xml` and the three `styles.xml`). Copy from there.

## Fallback

The animation never plays badly. Two cases get a still version instead:

| When | What the user sees |
|---|---|
| Reduce motion is on in the phone's settings | The finished logo for 0.9 s, then a 0.25 s fade into the first screen |
| The phone can't keep up | Checked on the first 12 frames (about 0.2 s in). If most of them miss the screen's refresh, the logo fades to its finished state, holds 0.9 s and fades into the first screen |

Change the hold with `staticHold: Duration(milliseconds: 600)`.

The phone check only runs in profile and release builds. Debug builds are always slow, so they always play the animation (choppily on weak phones). Judge smoothness with `flutter run --profile` or `--release`, never debug.

`skipOnSlowFrames: false` turns the check off. Use it only for screen recordings, where capturing slows every frame.

## Why it's light

- One animation controller repaints one canvas. Nothing rebuilds during the animation, nothing is laid out, nothing is decoded.
- Each frame fills about 15 shapes, plus two soft gradients during the spark.
- The first screen isn't drawn while the logo covers it.
- No assets: about 35 KB of Dart source, adding nothing to the download beyond that.

## Options

| Option | Default | |
|---|---|---|
| `child` | required | The first screen of the app |
| `onFinished` | none | Called once when the intro is gone |
| `onFallback` | none | Called with `GoEcFallback.slowPhone` or `.reducedMotion` if the still logo was shown. Handy for analytics |
| `staticHold` | 900 ms | How long the still logo stays up in the fallback |
| `skipOnSlowFrames` | `true` | The slow-phone check |
| `rollLetters` | `true` | g, o, c roll in like wheels; `false` slides them without turning |

## Changing the animation

- Timings: `_Timeline` at the top of `lib/src/goec_intro.dart`, every step in ms.
- Shapes: `lib/src/geometry.dart`, in pixels of the master logo artwork.

## Try it on its own

- Android app: [latest APK](https://github.com/Dhruvnathmenon/go-ec/releases/tag/demo). This is the real test of smoothness.
- Browser: [dhruvnathmenon.github.io/go-ec](https://dhruvnathmenon.github.io/go-ec/). Quick look only; a phone browser runs Flutter slower than the app does.

Both rebuild on every push to `main` (`.github/workflows/demo.yml`). After each run the demo says which version played and the frame rate. Tap to replay.

Locally:

```bash
cd example
flutter run --release
```

The example uses a still of the maps screen as `child`. Tests: `flutter test` in this folder.
