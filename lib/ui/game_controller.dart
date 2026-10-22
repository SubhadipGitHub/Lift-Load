import 'package:flutter/foundation.dart';

import '../game/cast.dart';
import '../game/debuts.dart';
import '../game/engine.dart';
import '../game/formulas.dart';
import '../game/generator.dart';
import '../game/level.dart';
import '../game/powers.dart';
import '../game/scenario.dart';
import '../services/ad_policy.dart';
import '../services/ads_service.dart';
import '../services/analytics_service.dart';
import '../services/feedback_service.dart';
import '../services/profile.dart';
import '../services/tester_log.dart';

/// Glue between the pure engine, the player's profile and the services.
/// Widgets read state from here and call these methods; nothing in the UI
/// touches the engine directly.
class GameController extends ChangeNotifier {
  GameController({
    required this.profile,
    required this.ads,
    required this.analytics,
    this.store,
    GameAudio? audio,
    FeedbackService? feedback,
    InterstitialPolicy? interstitials,
    DateTime Function()? clock,
    Level Function(int number)? levelFor,
    this.tester = const TesterConfig(),
    this.testerLog,
  })  : audio = audio ?? const SilentAudio(),
        feedback = feedback ?? FeedbackService(sfx: audio),
        interstitials = interstitials ?? InterstitialPolicy(clock: clock),
        _clock = clock ?? DateTime.now,
        _levelFor = levelFor ?? LevelGenerator.generate {
    _applySettings();
  }

  final Profile profile;
  final ProfileStore? store;
  final AdsService ads;
  final AnalyticsService analytics;
  final FeedbackService feedback;
  final GameAudio audio;
  final InterstitialPolicy interstitials;
  final DateTime Function() _clock;
  final Level Function(int) _levelFor;

  /// Gate A tester build: level cap, in-game questions, results export.
  final TesterConfig tester;
  final TesterLog? testerLog;

  LiftGame? _game;
  LiftGame get game => _game!;
  bool get hasGame => _game != null;

  String message = '';

  /// Moves since the play screen last looked, for walk animations.
  final List<Motion> _motions = [];

  /// Bumped when a resident is refused (they shake their head in [refused]
  /// place) or a coned-off lane is tapped ([coneLane] wobbles).
  int refuseSerial = 0;
  Selection? refused;
  int? _refusedId;
  int coneSerial = 0;
  int? coneLane;

  /// Bumped when an unknown person reaches a lane front ([revealedLane]), so
  /// the lobby can play the reveal.
  int revealSerial = 0;
  int? revealedLane;

  /// [refused], but only while the refused resident still stands there, so
  /// whoever steps up next does not replay their head-shake.
  Selection? get refusedSpot {
    final r = refused;
    if (r == null || !hasGame) return null;
    final here = r.fromBench ? game.bench[r.index] : game.frontOf(r.index);
    return here?.id == _refusedId ? r : null;
  }

  /// The power waiting for a second tap (only Swap needs one) and the first
  /// lane the player picked for it.
  Power? armedPower;
  int? swapFirstLane;

  /// Powers spent on this level, for analytics.
  int _powersUsed = 0;

  /// Coins a send just earned, for the coin burst; cleared when taken.
  int _pendingRewardCoins = 0;

  /// Where the selected resident stood when the player acted.
  Selection? _from;
  bool adInFlight = false;
  bool tripleClaimed = false;
  TripRating? _lastRating;
  int _lastRatingCoins = 0;

  /// Lobby news from the last send (rush-hour wave, lane opened), shown
  /// ahead of the "lift arriving" line instead of being overwritten by it.
  String _lobbyNews = '';
  bool _lifeSpentForThisFail = false;

  /// This level's attempt number (1 on the first try) and how many
  /// continues it has used, for analytics.
  int _attempt = 0;
  int _continues = 0;
  bool _crashRated = false;

  DateTime get now => _clock();

  // ── Level lifecycle ──

  // ── Settings ──

  void _applySettings() {
    audio
      ..soundOn = profile.soundOn
      ..musicOn = profile.musicOn;
    feedback.hapticsOn = profile.hapticsOn;
  }

  void setSound(bool on) => _setting(() => profile.soundOn = on, 'sound', on);
  void setMusic(bool on) => _setting(() => profile.musicOn = on, 'music', on);
  void setHaptics(bool on) => _setting(() => profile.hapticsOn = on, 'haptics', on);
  void setLeftHanded(bool on) => _setting(() => profile.leftHanded = on, 'left_handed', on);

  void _setting(void Function() apply, String name, bool on) {
    apply();
    _applySettings();
    analytics.log('setting_changed', {'setting': name, 'on': on});
    _save();
    feedback.tap();
    notifyListeners();
  }

  void startLevel() {
    if (testComplete) return;
    _motions.clear();
    _pendingRewardCoins = 0;
    refused = null;
    _refusedId = null;
    coneLane = null;
    armedPower = null;
    swapFirstLane = null;
    _powersUsed = 0;
    _game = LiftGame(_levelFor(profile.level));
    _lobbyNews = '';
    tripleClaimed = false;
    _lifeSpentForThisFail = false;
    final number = profile.level;
    _attempt = profile.attempts[number] = (profile.attempts[number] ?? 0) + 1;
    _continues = 0;
    _crashRated = false;
    _save();
    message = debutTip(game.level.number) ??
        scenarioTip(game.level.scenario) ??
        'Tap a resident, then the lift or a bench seat';
    audio.playVenue(game.level.venue);
    analytics.log('level_start', {
      'level': game.level.number,
      'difficulty': game.level.difficulty.name,
      'trips': game.tripsTotal,
      'venue': game.level.venue.name,
      if (game.level.scenario != null) 'scenario': game.level.scenario!.name,
      'attempt': _attempt,
      'lanes': game.laneCount,
      'unknown_share': (game.level.unknownIds.length * 100 / game.level.residentCount).round(),
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

  /// The player has seated someone, boarded someone or sent a lift, so
  /// leaving now gives up this attempt. Selecting alone does not count.
  bool get levelInProgress =>
      hasGame &&
      (game.phase == Phase.playing || game.phase == Phase.departing || game.phase == Phase.falling) &&
      (game.tripsUsed > 0 || game.riders.isNotEmpty || game.benchUsed > 0);

  /// Restart is free before the first move. After it, restarting gives up the
  /// attempt like a fail (one life) and, like Retry, needs a life left over
  /// to start again.
  bool get canRestart {
    if (game.phase != Phase.playing) return false;
    if (!levelInProgress) return true;
    profile.regenLives(now);
    return profile.lives > 1;
  }

  void restart() {
    if (!canRestart) {
      message = 'Restarting would use your last life. Finish this one first';
      notifyListeners();
      return;
    }
    if (levelInProgress) _abandon('restart');
    startLevel();
  }

  void quitToHome() {
    if (hasGame && game.phase == Phase.failed) {
      _spendLifeForFail();
    } else if (levelInProgress) {
      _abandon('quit');
    }
    notifyListeners();
  }

  /// Leaving a level in progress costs one life, the same as failing it, so
  /// a bad start cannot be dodged for free.
  void _abandon(String via) {
    analytics.log('level_abandon', {
      'level': game.level.number,
      'via': via,
      'trips_used': game.tripsUsed,
      'attempt': _attempt,
      'powers_used': _powersUsed,
    });
    profile.spendLife(now);
    profile.winStreak = 0;
    _save();
  }

  // ── Gate A tester build ──

  /// The tester has cleared every level Gate A measures.
  bool get testComplete => tester.enabled && profile.level > TesterConfig.lastLevel;

  /// One optional tap on the crash sheet; asked on the spot, once per crash.
  bool get askCrashFair =>
      tester.enabled && hasGame && game.phase == Phase.failed && game.failKind == FailKind.crash && !_crashRated;

  void rateCrash({required bool fair}) {
    if (!askCrashFair) return;
    _crashRated = true;
    analytics.log('crash_fairness', {'level': game.level.number, 'attempt': _attempt, 'fair': fair});
    notifyListeners();
  }

  /// The unprompted "which residents are heaviest?" question, once, on the
  /// first win from level 15 on.
  bool get askHeavyTypes =>
      tester.enabled &&
      testerLog != null &&
      !testerLog!.heavyTypesAsked &&
      hasGame &&
      game.phase == Phase.won &&
      game.level.number >= TesterConfig.heavyTypesAfterLevel;

  void answerHeavyTypes(String? answer) {
    if (!askHeavyTypes) return;
    final text = answer?.trim() ?? '';
    analytics.log('exit_heavy_types', {'level': game.level.number, 'answer': text, 'skipped': text.isEmpty});
    notifyListeners();
  }

  // ── Player input ──

  void tapQueue(int lane) {
    if (game.phase == Phase.playing && game.isLaneLocked(lane)) {
      coneSerial++;
      coneLane = lane;
      final n = game.tripsUntilLaneOpens;
      message = 'Closed for maintenance. Opens in $n ${n == 1 ? 'trip' : 'trips'}';
      notifyListeners();
      return;
    }
    if (armedPower == Power.swap) {
      _pickSwapLane(lane);
      return;
    }
    game.tapQueue(lane);
    _afterAction();
  }

  void tapBench(int seat) {
    cancelPower();
    _from = game.selection;
    final r = game.tapBench(seat);
    if (r == BenchResult.needSelection) message = 'Pick someone from the queue first';
    _afterAction();
  }

  void tapLift() {
    cancelPower();
    _from = game.selection;
    final r = game.tapLift();
    if (r == BoardResult.noSelection) message = 'Select a resident first';
    _afterAction();
  }

  void send() {
    cancelPower();
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

  // ── Powers (PRD v1.6) ──

  /// The power has been unlocked by this level.
  bool powerUnlocked(Power p) => hasGame && game.level.number >= p.unlockLevel;

  int powerStock(Power p) => profile.stock(p);

  /// Whether a tap on [p] would do something right now: unlocked, and the
  /// engine allows it. An empty stock still counts: the tap opens a refill.
  bool powerUsable(Power p) => powerUnlocked(p) && game.canUsePower(p);

  /// Tap on a power button. With stock it acts (Swap arms and waits for two
  /// lanes); without, it logs the tap and leaves the UI to offer a refill.
  void usePower(Power p) {
    if (!hasGame || game.phase != Phase.playing || adInFlight) return;
    if (!powerUnlocked(p)) {
      message = '${p.name} unlocks on level ${p.unlockLevel}';
      notifyListeners();
      return;
    }
    if (armedPower == p) {
      cancelPower();
      return;
    }
    cancelPower(quiet: true);
    if (!game.canUsePower(p)) {
      message = _powerBlocked(p);
      notifyListeners();
      return;
    }
    if (profile.stock(p) <= 0) {
      analytics.log('power_empty_tapped', {'power': p.name, 'level': game.level.number});
      message = 'No ${p.name} left. Watch an ad or spend coins';
      notifyListeners();
      return;
    }
    if (p == Power.swap) {
      armedPower = p;
      swapFirstLane = null;
      message = 'Swap: tap the first lane';
      notifyListeners();
      return;
    }
    final done = switch (p) {
      Power.seats => game.addSeats(),
      Power.trip => game.addTrip(),
      Power.express => game.expressDeliver() != null,
      Power.swap => false,
    };
    if (done) _spentPower(p);
    _afterAction();
  }

  String _powerBlocked(Power p) => game.powerUses(p) >= Formulas.powerCap(p)
      ? 'Already used on this level'
      : switch (p) {
          Power.swap => 'Swap needs two lanes with people in them',
          Power.express => 'Select someone first, then Express',
          Power.seats || Power.trip => 'Not available right now',
        };

  void cancelPower({bool quiet = false}) {
    if (armedPower == null) return;
    armedPower = null;
    swapFirstLane = null;
    if (!quiet) {
      message = 'Tap a resident, then the lift or a bench seat';
      notifyListeners();
    }
  }

  void _pickSwapLane(int lane) {
    if (game.isLaneLocked(lane) || game.frontOf(lane) == null) {
      message = 'Pick a lane with someone at the front';
      notifyListeners();
      return;
    }
    final first = swapFirstLane;
    if (first == null) {
      swapFirstLane = lane;
      message = 'Swap: now tap the second lane';
      notifyListeners();
      return;
    }
    if (first == lane) {
      cancelPower();
      return;
    }
    if (game.swapFronts(first, lane)) _spentPower(Power.swap);
    armedPower = null;
    swapFirstLane = null;
    _afterAction();
  }

  void _spentPower(Power p) {
    profile.spendPower(p);
    _powersUsed++;
    analytics.log('power_used', {
      'power': p.name,
      'level': game.level.number,
      'left': profile.stock(p),
      'trips_used': game.tripsUsed,
    });
    _save();
  }

  /// Stock can be bought only for a power the player has reached, so a stale
  /// sheet cannot spend coins on something locked.
  bool _powerReached(Power p) => profile.level >= p.unlockLevel;

  bool canBuyPower(Power p) => _powerReached(p) && profile.coins >= Formulas.powerCoinPrice(p);

  void buyPowerWithCoins(Power p) {
    if (!canBuyPower(p)) return;
    profile.coins -= Formulas.powerCoinPrice(p);
    profile.addPower(p, 1);
    analytics.log('power_bought', {
      'power': p.name,
      'coins': Formulas.powerCoinPrice(p),
      'level': hasGame ? game.level.number : 0,
    });
    _save();
    notifyListeners();
  }

  /// Offered only mid-level, never over a send or crash animation.
  bool canAdForPower(Power p) =>
      hasGame &&
      game.phase == Phase.playing &&
      _powerReached(p) &&
      !adInFlight &&
      profile.rewarded.canShow(RewardedPlacement.powerRefill, now);

  /// One ad, [Formulas.powerAdUses] uses of [p]; granted only when the SDK
  /// reports the reward earned.
  Future<void> adForPower(Power p) async {
    if (!canAdForPower(p)) return;
    final ok = await _showRewarded(RewardedPlacement.powerRefill);
    if (!ok) return;
    profile.addPower(p, Formulas.powerAdUses);
    analytics.log('power_refill_ad', {
      'power': p.name,
      'level': hasGame ? game.level.number : 0,
      if (ads is StubAdsService) 'stub': true,
    });
    _save();
    notifyListeners();
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

  bool get canAdForLife =>
      profile.lives < Formulas.maxLives && profile.rewarded.canShow(RewardedPlacement.extraLife, now);

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
    if (testComplete) return;
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
        case SeatedEvent(:final resident, :final seat):
          if (_from case final from?) _motions.add(Motion(resident, from, MotionTarget.seat(seat)));
          message = 'Seated on the bench';
        case RefusedEvent(:final resident, :final liftFloors):
          refuseSerial++;
          refused = _from;
          _refusedId = resident.id;
          message = 'This lift goes to ${floorList(liftFloors)}. They live on ${resident.floor.label}.';
        case BoardedEvent(:final resident, :final zone):
          if (_from case final from?) _motions.add(Motion(resident, from, const MotionTarget.cabin()));
          message = switch (zone) {
            LoadZone.light || LoadZone.empty => 'Still light. Room for more?',
            LoadZone.green => 'In the green. Send now, or risk one more',
            LoadZone.limit => 'Right at the limit!',
            LoadZone.overload => 'Overloaded!',
          };
        case OverloadEvent(:final resident):
          if (_from case final from?) _motions.add(Motion(resident, from, const MotionTarget.cabin()));
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
          _pendingRewardCoins = coins;
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
        case ArrivalsEvent():
          _lobbyNews += 'Rush hour: a crowd joined the queues · ';
          message = 'Rush hour! A crowd joined the queues';
        case LaneOpenedEvent(:final lane):
          _lobbyNews += 'Lane ${lane + 1} open · ';
          message = 'Maintenance done. Lane ${lane + 1} is open';
        case ScalePreviewEvent():
          message = 'The dashed needle shows where the load would land';
        case RevealedEvent(:final lane):
          revealSerial++;
          revealedLane = lane;
          analytics.log('unknown_revealed', {'level': game.level.number, 'lane': lane});
          message = 'Someone new stepped up in lane ${lane + 1}';
        case SwapEvent():
          message = 'Swapped the two fronts';
        case SeatsAddedEvent():
          message = 'More bench seats';
        case TripAddedEvent():
          message = 'One more trip';
        case ExpressEvent(:final resident):
          message = 'Express! They went straight to ${resident.floor.label}';
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
            'attempt': _attempt,
            'continues': _continues,
            'powers_used': _powersUsed,
          });
          if (tester.enabled && game.level.number == TesterConfig.lastLevel) {
            analytics.log('test_complete', {'level': game.level.number});
          }
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
            'attempt': _attempt,
            'powers_used': _powersUsed,
          });
        case ContinuedEvent(:final kind, :final seatsAdded):
          _lifeSpentForThisFail = false;
          _continues++;
          _crashRated = false;
          final seats = seatsLabel(seatsAdded);
          message = switch (kind) {
            FailKind.crash => 'Lift repaired. They are back where they stood',
            FailKind.outOfTrips => '+${Formulas.adTripsBonus} trips${seats.isEmpty ? '' : ' and $seats'}',
            FailKind.jam => seats,
          };
      }
    }
    notifyListeners();
  }

  void _save() => store?.save(profile);

  /// Moves recorded since the last call, oldest first.
  List<Motion> takeMotions() {
    final out = List.of(_motions);
    _motions.clear();
    return out;
  }

  /// The rating of the trip just sent, from the send until the next lift
  /// arrives (null otherwise): the play screen's score slam. It says only
  /// what the message line says on arrival, never anything about a weight.
  TripRating? get sentRating => _lastRating;

  /// Coins the last send earned (0 for a grey trip), once.
  int takeReward() {
    final c = _pendingRewardCoins;
    _pendingRewardCoins = 0;
    return c;
  }

  /// Accessibility label for a resident: type, cargo and floor, never weight.
  static String describe(Resident r) =>
      '${r.type.displayName}${r.cargo == Cargo.none ? '' : ' with a ${r.cargo.displayName}'} going to ${r.floor.label}';

  /// "+1 bench seat", "+2 bench seats", or empty for none. Where the level has
  /// unknown people the count is left out: how many seats a jam needs would
  /// say how deep a matching person stands.
  String seatsLabel(int n) {
    if (n <= 0) return '';
    if (hasGame && game.level.unknownIds.isNotEmpty) return 'more bench seats';
    return '+$n bench ${n == 1 ? 'seat' : 'seats'}';
  }

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
        UnknownDebut() => 'Some people in the queue are a mystery until they reach the front',
        LaneDebut() => 'The lobby now has a different number of lanes from level to level',
        PowerDebut(:final power) => powerTip(power),
        null => null,
      };

  /// One line for a power's unlock, and for its button. Never hints at weight.
  static String powerTip(Power p) => switch (p) {
        Power.swap => 'New power: Swap trades the front people of two lanes',
        Power.seats => 'New power: +2 seats adds two bench seats',
        Power.trip => 'New power: +1 trip adds a trip',
        Power.express => 'New power: Express sends the selected person straight to their floor',
      };

  static String? scenarioTip(Scenario? s) => switch (s) {
        Scenario.maintenance => 'One lane is closed for maintenance for the first trips',
        Scenario.rushHour => 'Rush hour: more residents will arrive',
        null => null,
      };
}

/// Where a moving resident ends up.
class MotionTarget {
  const MotionTarget.seat(int this.seat);
  const MotionTarget.cabin() : seat = null;

  /// Bench seat index, or null for the lift cabin.
  final int? seat;
}

/// One resident walking from a lane front or seat to a seat or the cabin.
/// Every resident walks the same way: nothing here depends on weight.
class Motion {
  const Motion(this.resident, this.from, this.to);

  final Resident resident;
  final Selection from;
  final MotionTarget to;
}
