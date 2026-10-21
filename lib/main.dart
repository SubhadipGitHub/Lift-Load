import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/ads_service.dart';
import 'services/analytics_service.dart';
import 'services/profile.dart';
import 'ui/game_controller.dart';
import 'ui/layout.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Phones stay portrait; tablets may rotate and get the two-pane layout.
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final shortest = view.physicalSize.shortestSide / view.devicePixelRatio;
  await SystemChrome.setPreferredOrientations(
    shortest >= Metrics.tabletShortestSide ? const [] : const [DeviceOrientation.portraitUp],
  );

  final store = await ProfileStore.open();
  // M1: stubbed ads and console analytics. M3 swaps in AdMob and Firebase
  // implementations of the same interfaces.
  final ads = StubAdsService();
  await ads.init();

  final controller = GameController(
    profile: store.load(DateTime.now()),
    store: store,
    ads: ads,
    analytics: DebugAnalytics(),
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
          ),
          child: child!,
        ),
        home: HomeScreen(controller: controller),
      );
}
