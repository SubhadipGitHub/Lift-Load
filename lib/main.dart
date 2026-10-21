import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/ads_service.dart';
import 'services/analytics_service.dart';
import 'services/audio_service.dart';
import 'services/profile.dart';
import 'ui/game_controller.dart';
import 'ui/layout.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await ProfileStore.open();
  // M1: stubbed ads and console analytics. M3 swaps in AdMob and Firebase
  // implementations of the same interfaces.
  final ads = StubAdsService();
  await ads.init();

  // Synthesized cues and venue music. Loading runs in the background so the
  // first frame is not held up; music starts on the first Play tap.
  final audio = AudioService();
  unawaited(audio.init());
  // Quiet in the background, back on return.
  AppLifecycleListener(onHide: audio.pause, onShow: audio.resume);

  final controller = GameController(
    profile: store.load(DateTime.now()),
    store: store,
    ads: ads,
    analytics: DebugAnalytics(),
    audio: audio,
  );
  runApp(LiftLoadApp(controller: controller));
}

class LiftLoadApp extends StatelessWidget {
  const LiftLoadApp({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Lift Load',
        debugShowCheckedModeBanner: false,
        theme: LL.theme(),
        // Large system text is honoured up to 1.3x; past that rows would break.
        builder: (context, child) {
          _fitOrientation(MediaQuery.sizeOf(context));
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
            ),
            child: child!,
          );
        },
        home: HomeScreen(controller: controller),
      );
}

/// Phones stay portrait; tablets may rotate and get the two-pane layout.
/// Decided from the laid-out size rather than at startup, where Android can
/// still report a zero window, and re-decided when the window changes size
/// (a foldable opening). Unknown sizes leave rotation alone.
bool? _rotates;

void _fitOrientation(Size size) {
  if (size.isEmpty) return;
  final rotates = size.shortestSide >= Metrics.tabletShortestSide;
  if (rotates == _rotates) return;
  _rotates = rotates;
  SystemChrome.setPreferredOrientations(rotates ? const [] : const [DeviceOrientation.portraitUp]);
}
