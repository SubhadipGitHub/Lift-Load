/// Pure-Dart ad rules from docs/PRD.md "Monetization". Kept separate from
/// the SDK so the rules are unit-tested and the SDK can be swapped.
library;

/// Rewarded placements. Each has a cap enforced by [RewardedBudget].
enum RewardedPlacement {
  repairLift,
  extraTrips,
  extraSeat,
  tripleCoins,
  preHardScale,
  extraLife,
  dailyChest;

  /// Daily cap per placement; null = governed only by the per-attempt rule.
  int? get dailyCap => switch (this) {
        RewardedPlacement.extraLife => 3,
        RewardedPlacement.dailyChest => 1,
        _ => null,
      };
}

/// Interstitial gating: only after a win, from level 15, at least 3 levels
/// and 180 s since the last ad of any kind, at most 4 per session, never for
/// players who paid.
class InterstitialPolicy {
  InterstitialPolicy({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const int firstLevel = 15;
  static const int levelsBetween = 3;
  static const Duration minGap = Duration(seconds: 180);
  static const int perSession = 4;

  final DateTime Function() _clock;
  int _shownThisSession = 0;
  int? _lastLevelShown;
  DateTime? _lastAdAt;

  /// Record any ad (rewarded too) so the time gap covers both.
  void recordAnyAd() => _lastAdAt = _clock();

  bool shouldShowAfterWin({required int levelJustWon, required bool isPayer}) {
    if (isPayer) return false;
    if (levelJustWon < firstLevel) return false;
    if (_shownThisSession >= perSession) return false;
    final last = _lastLevelShown;
    if (last != null && levelJustWon - last < levelsBetween) return false;
    final at = _lastAdAt;
    if (at != null && _clock().difference(at) < minGap) return false;
    return true;
  }

  void recordInterstitial(int level) {
    _shownThisSession++;
    _lastLevelShown = level;
    recordAnyAd();
  }
}

/// 12 rewarded views a day in total, plus per-placement daily caps.
class RewardedBudget {
  RewardedBudget({required this.day, Map<String, int>? used}) : used = used ?? {};

  static const int dailyTotal = 12;

  /// yyyy-mm-dd of the counters.
  String day;
  final Map<String, int> used;

  static String dayKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  void rollTo(DateTime now) {
    final k = dayKey(now);
    if (k != day) {
      day = k;
      used.clear();
    }
  }

  int get totalToday => used.values.fold(0, (a, b) => a + b);

  bool canShow(RewardedPlacement p, DateTime now) {
    rollTo(now);
    if (totalToday >= dailyTotal) return false;
    final cap = p.dailyCap;
    return cap == null || (used[p.name] ?? 0) < cap;
  }

  void record(RewardedPlacement p, DateTime now) {
    rollTo(now);
    used[p.name] = (used[p.name] ?? 0) + 1;
  }
}
