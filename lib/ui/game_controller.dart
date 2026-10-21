import 'package:flutter/foundation.dart';

import '../game/cast.dart';
import '../game/debuts.dart';
import '../game/engine.dart';
import '../game/formulas.dart';
import '../game/generator.dart';
import '../game/level.dart';
import '../game/scenario.dart';
import '../services/ad_policy.dart';
import '../services/ads_service.dart';
import '../services/analytics_service.dart';
import '../services/feedback_service.dart';
import '../services/profile.dart';

/// Glue between the pure engine, the player's profile and the services.
/// Widgets read state from here and call these methods; nothing in the UI
/// touches the engine directly.
class GameController extends ChangeNotifier {
  GameController({
    required this.profile,
    required this.ads,
    required this.analytics,
    this.store,
    FeedbackService? feedback,
    InterstitialPolicy? interstitials,
    DateTime Function()? clock,
    Level Function(int number)? levelFor,
  })  : feedback = feedback ?? FeedbackService(),
        interstitials = interstitials ?? InterstitialPolicy(clock: clock),
        _clock = clock ?? DateTime.now,
        _levelFor = levelFor ?? LevelGenerator.generate;

  final Profile profile;
  final ProfileStore? store;
  final AdsService ads;
  final AnalyticsService analytics;
  final FeedbackService feedback;
  final InterstitialPolicy interstitials;
  final DateTime Function() _clock;
  final Level Function(int) _levelFor;

  LiftGame? _game;
  LiftGame get game => _game!;
  bool get hasGame => _game != null;

  String message = '';
  bool adInFlight = false;
  bool tripleClaimed = false;
  TripRating? _lastRating;
  int _lastRatingCoins = 0;

  /// Lobby news from the last send (rush-hour wave, lane opened), shown
  /// ahead of the "lift arriving" line instead of being overwritten by it.
  String _lobbyNews = '';
  bool _lifeSpentForThisFail = false;

  DateTime get now => _clock();

  // ── Level lifecycle ──

  void startLevel() {
    _game = LiftGame(_levelFor(profile.level));
    _lobbyNews = '';
    tripleClaimed = false;
    _lifeSpentForThisFail = false;
    message = debutTip(game.level.number) ?? scenarioTip(game.level.scenario) ?? 'Tap a resident, then the lift or a bench seat';
    analytics.log('level_start', {
      'level': game.level.number,
      'difficulty': game.level.difficulty.name,
      'trips': game.tripsTotal,
      'venue': game.level.venue.name,
      if (game.level.scenario != null) 'scenario': game.level.scenario!.name,
    });
    notifyListeners();
  }

  bool get canRetry {
    profile.regenLives(now);
    return profile.lives > 0;
  }

  /// Leaving a failed level costs one life (once per fail).
  void _spendLifeForFail() {
    if (_lifeSpentForThisFail || game.phase != Phase.failed) return;
    _lifeSpentForThisFail = true;
    profile.spendLife(now);
    profile.winStreak = 0;
    _save();
  }

  void retry() {
    _spendLifeForFail();
    if (profile.lives <= 0) {
      message = 'Out of lives. Watch an ad for one, or wait for the next.';
      notifyListeners();
      return;
    }
    startLevel();
  }

  void quitToHome() {
    if (hasGame && game.phase == Phase.failed) _spendLifeForFail();
    notifyListeners();
  }

  // ── Player input ──

  void tapQueue(int lane) {
    if (game.phase == Phase.playing && game.isLaneLocked(lane)) {
      final n = game.tripsUntilLaneOpens;
      message = 'Closed for maintenance. Opens in $n ${n == 1 ? 'trip' : 'trips'}';
      notifyListeners();
      return;
    }
    game.tapQueue(lane);
    _afterAction();
  }

  void tapBench(int seat) {
    final r = game.tapBench(seat);
    if (r == BenchResult.needSelection) message = 'Pick someone from the queue first';
    _afterAction();
  }

  void tapLift() {
    final r = game.tapLift();
    if (r == BoardResult.noSelection) message = 'Select a resident first';
    _afterAction();
  }

  void send() {
    game.send();
    _afterAction();
  }

  /// Called by the play screen when the departure animation ends.
  void finishSend() {
    game.finishSend();
    _afterAction();
  }

  /// Called by the play screen when the crash animation ends.
  void finishCrash() {
    game.finishCrash();
    _afterAction();
  }

  bool get canUseScale {
    final r = game.selected;
    return game.phase == Phase.playing && profile.scales > 0 && r != null && game.goesTo(r.floor);
  }

  void useScale() {
    if (profile.scales <= 0) {
      message = 'No Scale left. Get more in the shop';
    } else if (!canUseScale) {
      message = 'Select someone for this lift, then use Scale';
    } else if (game.previewScale()) {
      profile.scales--;
      analytics.log('scale_used', {'level': game.level.number, 'left': profile.scales});
      _save();
    }
    _afterAction();
  }

  // ── Continues and rewards ──

  RewardedPlacement? get _failPlacement => switch (game.failKind) {
        FailKind.crash => RewardedPlacement.repairLift,
        FailKind.outOfTrips => RewardedPlacement.extraTrips,
        FailKind.jam => RewardedPlacement.extraSeat,
        null => null,
      };

  bool get canContinueWithAd {
    final p = _failPlacement;
    return game.phase == Phase.failed && !game.adContinueUsed && p != null && profile.rewarded.canShow(p, now);
  }

  bool get canContinueWithCoins => game.phase == Phase.failed && profile.coins >= Formulas.coinContinuePrice;

  Future<void> continueWithAd() async {
    final p = _failPlacement;
    if (p == null || !canContinueWithAd || adInFlight) return;
    final ok = await _showRewarded(p);
    if (!ok) return;
    game.continueAfterFail(viaAd: true);
    _afterAction();
  }

  void continueWithCoins() {
    if (!canContinueWithCoins) return;
    profile.coins -= Formulas.coinContinuePrice;
    analytics.log('coin_continue', {'level': game.level.number, 'kind': game.failKind!.name});
    game.continueAfterFail(viaAd: false);
    _save();
    _afterAction();
  }

  bool get canTriple =>
      game.phase == Phase.won && !tripleClaimed && profile.rewarded.canShow(RewardedPlacement.tripleCoins, now);

  Future<void> claimTriple() async {
    if (!canTriple || adInFlight) return;
    final ok = await _showRewarded(RewardedPlacement.tripleCoins);
    if (!ok) return;
    tripleClaimed = true;
    profile.coins += game.levelCoins * 2; // base award was paid on the win
    _save();
    notifyListeners();
  }

  bool get canAdForLife => profile.lives < Formulas.maxLives && profile.rewarded.canShow(RewardedPlacement.extraLife, now);

  Future<void> adForLife() async {
    if (!canAdForLife || adInFlight) return;
    final ok = await _showRewarded(RewardedPlacement.extraLife);
    if (!ok) return;
    profile.lives = (profile.lives + 1).clamp(0, Formulas.maxLives).toInt();
    _save();
    notifyListeners();
  }

  /// From the win screen. May show an interstitial first, per the policy.
  Future<void> nextLevel() async {
    final won = game.level.number;
    if (interstitials.shouldShowAfterWin(levelJustWon: won, isPayer: profile.adsRemoved)) {
      adInFlight = true;
      notifyListeners();
      await ads.showInterstitial();
      interstitials.recordInterstitial(won);
      analytics.log('interstitial_shown', {'level': won});
      adInFlight = false;
    }
    startLevel();
  }

  Future<bool> _showRewarded(RewardedPlacement p) async {
    adInFlight = true;
    analytics.log('rewarded_offer_accepted', {'placement': p.name, 'level': hasGame ? game.level.number : 0});
    notifyListeners();
    final ok = await ads.showRewarded(p);
    adInFlight = false;
    interstitials.recordAnyAd();
    if (ok) {
      profile.rewarded.record(p, now);
      analytics.log('rewarded_complete', {'placement': p.name});
      _save();
    } else {
      message = 'Ad not completed. No reward this time';
    }
    notifyListeners();
    return ok;
  }

  // ── Events → messages, feedback, analytics, profile ──

  void _afterAction() {
    for (final e in game.drainEvents()) {
      feedback.on(e);
      switch (e) {
        case SelectedEvent():
          message = 'Tap the lift, or an empty bench seat';
        case SeatedEvent():
          message = 'Seated on the bench';
        case RefusedEvent(:final resident, :final liftFloors):
          message = 'This lift goes to ${floorList(liftFloors)}. They live on ${resident.floor.label}.';
        case BoardedEvent(:final zone):
          message = switch (zone) {
            LoadZone.light || LoadZone.empty => 'Still light. Room for more?',
            LoadZone.green => 'In the green. Send now, or risk one more',
            LoadZone.limit => 'Right at the limit!',
            LoadZone.overload => 'Overloaded!',
          };
        case OverloadEvent(:final resident):
          message = 'Overloaded! The cable snapped';
          analytics.log('overload', {
            'level': game.level.number,
            'type': resident.type.name,
            'cargo': resident.cargo.name,
            'lift_kind': game.liftKind.name,
            if (game.level.scenario != null) 'scenario': game.level.scenario!.name,
            'riders': game.riders.length,
          });
        case SentEvent(:final floors, :final kind, :final rating, :final coins, :final riders):
          _lastRating = rating;
          _lastRatingCoins = coins;
          message = 'Ding! Going up to ${floorList(floors)}';
          analytics.log('trip_sent', {
            'level': game.level.number,
            'rating': rating.name,
            'fill_pct': (game.loadFraction * 100).round(),
            'riders': riders,
            'lift_kind': kind.name,
          });
        case LiftArrivedEvent(:final floors, :final kind):
          final verdict = switch (_lastRating) {
            TripRating.perfect => 'Perfect load! +$_lastRatingCoins · ',
            TripRating.good => 'Good trip +$_lastRatingCoins · ',
            TripRating.halfEmpty => 'Half-empty trip · ',
            null => '',
          };
          _lastRating = null;
          final news = _lobbyNews;
          _lobbyNews = '';
          final lift = switch (kind) {
            LiftKind.normal => 'Lift',
            LiftKind.old => 'Old lift (it takes less)',
            LiftKind.service => 'Service lift (it takes more)',
            LiftKind.express => 'Express',
          };
          message = '$news$verdict$lift to ${floorList(floors)} arriving';
        case ArrivalsEvent(:final count):
          _lobbyNews += 'Rush hour: +$count in the queues · ';
          message = 'Rush hour! $count more residents joined the queues';
        case LaneOpenedEvent(:final lane):
          _lobbyNews += 'Lane ${lane + 1} open · ';
          message = 'Maintenance done. Lane ${lane + 1} is open';
        case ScalePreviewEvent():
          message = 'The dashed needle shows where the load would land';
        case WonEvent(:final coins, :final tripsUsed, :final perfects):
          message = 'Everyone is home!';
          profile
            ..coins += coins
            ..level += 1
            ..winStreak += 1;
          analytics.log('level_win', {
            'level': game.level.number,
            'venue': game.level.venue.name,
            'trips_used': tripsUsed,
            'trips_total': game.tripsTotal,
            'perfects': perfects,
            'coins': coins,
          });
          _save();
        case FailedEvent(:final kind):
          message = switch (kind) {
            FailKind.crash => 'Overloaded! The lift dropped',
            FailKind.outOfTrips => 'Out of trips',
            FailKind.jam => 'Lobby jammed',
          };
          analytics.log('level_fail', {
            'level': game.level.number,
            'venue': game.level.venue.name,
            if (game.level.scenario != null) 'scenario': game.level.scenario!.name,
            'kind': kind.name,
            'trips_used': game.tripsUsed,
          });
        case ContinuedEvent(:final kind):
          _lifeSpentForThisFail = false;
          message = switch (kind) {
            FailKind.crash => 'Lift repaired. They are back where they stood',
            FailKind.outOfTrips => '+${Formulas.adTripsBonus} trips',
            FailKind.jam => '+1 bench seat',
          };
      }
    }
    notifyListeners();
  }

  void _save() => store?.save(profile);

  /// Accessibility label for a resident: type, cargo and floor, never weight.
  static String describe(Resident r) =>
      '${r.type.displayName}${r.cargo == Cargo.none ? '' : ' with a ${r.cargo.displayName}'} going to ${r.floor.label}';

  /// "2F" or "2F and 5F".
  static String floorList(List<Floor> floors) => floors.map((f) => f.label).join(' and ');

  /// One line introducing whatever debuts on [level]. Never hints at weight.
  static String? debutTip(int level) => switch (Debut.at(level)) {
        TypeDebut(:final type) => 'New in the lobby: ${type.displayName}. Watch the needle',
        CargoDebut(:final cargo) => 'Some residents carry a ${cargo.displayName} today. It counts too',
        LiftDebut(kind: LiftKind.old) => 'Old lifts are coming. Their cable takes less',
        LiftDebut(kind: LiftKind.service) => 'Service lifts are coming. They take more',
        LiftDebut(kind: LiftKind.express) => 'Express lifts stop at two floors in one trip',
        LiftDebut(kind: LiftKind.normal) => null,
        ScenarioDebut(:final scenario) => scenarioTip(scenario),
        null => null,
      };

  static String? scenarioTip(Scenario? s) => switch (s) {
        Scenario.maintenance => 'One lane is closed for maintenance for the first trips',
        Scenario.powerCut => 'Power cut! You only see who is near the front',
        Scenario.rushHour => 'Rush hour: more residents will arrive',
        null => null,
      };
}
