import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/services/ad_policy.dart';

void main() {
  group('InterstitialPolicy', () {
    late DateTime now;
    late InterstitialPolicy policy;

    setUp(() {
      now = DateTime(2026, 10, 21, 18);
      policy = InterstitialPolicy(clock: () => now);
    });

    test('never before level 15 and never for payers', () {
      expect(policy.shouldShowAfterWin(levelJustWon: 14, isPayer: false), isFalse);
      expect(policy.shouldShowAfterWin(levelJustWon: 15, isPayer: true), isFalse);
      expect(policy.shouldShowAfterWin(levelJustWon: 15, isPayer: false), isTrue);
    });

    test('three levels and 180 seconds apart', () {
      policy.recordInterstitial(15);
      now = now.add(const Duration(minutes: 10));
      expect(policy.shouldShowAfterWin(levelJustWon: 17, isPayer: false), isFalse);
      expect(policy.shouldShowAfterWin(levelJustWon: 18, isPayer: false), isTrue);
      policy.recordAnyAd(); // a rewarded ad just played
      expect(policy.shouldShowAfterWin(levelJustWon: 18, isPayer: false), isFalse);
      now = now.add(const Duration(seconds: 181));
      expect(policy.shouldShowAfterWin(levelJustWon: 18, isPayer: false), isTrue);
    });

    test('at most four per session', () {
      for (var i = 0; i < 4; i++) {
        policy.recordInterstitial(15 + i * 3);
        now = now.add(const Duration(minutes: 5));
      }
      expect(policy.shouldShowAfterWin(levelJustWon: 40, isPayer: false), isFalse);
    });
  });

  group('RewardedBudget', () {
    test('12 per day in total, extra life capped at 3, resets next day', () {
      final day1 = DateTime(2026, 10, 21, 9);
      final b = RewardedBudget(day: RewardedBudget.dayKey(day1));
      for (var i = 0; i < 3; i++) {
        expect(b.canShow(RewardedPlacement.extraLife, day1), isTrue);
        b.record(RewardedPlacement.extraLife, day1);
      }
      expect(b.canShow(RewardedPlacement.extraLife, day1), isFalse);
      for (var i = 0; i < 9; i++) {
        b.record(RewardedPlacement.repairLift, day1);
      }
      expect(b.totalToday, 12);
      expect(b.canShow(RewardedPlacement.tripleCoins, day1), isFalse);
      final day2 = day1.add(const Duration(days: 1));
      expect(b.canShow(RewardedPlacement.extraLife, day2), isTrue);
      expect(b.totalToday, 0);
    });
  });
}
