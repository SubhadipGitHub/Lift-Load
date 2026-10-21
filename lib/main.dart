import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/ads_service.dart';
import 'services/analytics_service.dart';
import 'services/profile.dart';
import 'ui/game_controller.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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
        home: HomeScreen(controller: controller),
      );
}
