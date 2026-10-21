import 'package:flutter/foundation.dart';

import 'ad_policy.dart';

/// Ad SDK boundary. M1 ships [StubAdsService]; M3 adds an AdMob
/// implementation (google_mobile_ads) behind this same interface.
///
/// Contract: [showRewarded] completes `true` ONLY when the SDK reports the
/// reward was earned, never merely because the ad closed.
abstract interface class AdsService {
  Future<void> init();

  /// Whether a rewarded ad is loaded and can be shown now.
  bool get rewardedReady;

  Future<bool> showRewarded(RewardedPlacement placement);

  Future<void> showInterstitial();
}

/// Development stand-in: every rewarded ad "completes" after a short delay
/// so flows can be played end to end in the browser build.
class StubAdsService implements AdsService {
  StubAdsService({this.delay = const Duration(milliseconds: 700), this.grantReward = true});

  final Duration delay;
  final bool grantReward;

  @override
  Future<void> init() async {}

  @override
  bool get rewardedReady => true;

  @override
  Future<bool> showRewarded(RewardedPlacement placement) async {
    debugPrint('[ads] rewarded ${placement.name} (stub)');
    await Future<void>.delayed(delay);
    return grantReward;
  }

  @override
  Future<void> showInterstitial() async {
    debugPrint('[ads] interstitial (stub)');
    await Future<void>.delayed(delay);
  }
}
