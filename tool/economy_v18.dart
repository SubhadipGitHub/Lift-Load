// Coin-income model for PRD v1.8 ("Economy"): how much more does a level pay
// with the combo, VIP and hurry tips and the golden lift, and what trip-coin
// values hold the cap of +25% per level? `dart run tool/economy_v18.dart [from] [to]`.
//
// One bot plays every level with the level's real trip budget: the blind bot
// of tool/blind_study.dart (it knows the cast's weights like a practised
// player, but aims only at people it can see). Each send's rating comes from
// its fill (grey < 75%, green >= 75%, perfect >= 95%), then the same play is
// priced under today's rules and under v1.8. Coins count only on a win.
//
// The v1.8 extras that depend on things the bot cannot model are expected
// values, stated as assumptions below (one VIP per level from 24, one hurry
// resident per level from 35, one golden lift in six from 44). Smooth-exit
// bonuses (World 2 express lifts) and the daily challenge are left out: the
// first is a few coins, the second is per day, not per level.
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/generator.dart';

import 'blind_study.dart' as blind;

/// v1.8 numbers from docs/PRD-v1.8-vibrant.md (C, D, F).
const List<double> comboSteps = [1, 1.5, 2, 3]; // by green-or-better sends in a row before this one
const List<double> comboStepsCap2 = [1, 1.5, 2, 2];
const int vipTip = 10, vipFrom = 24;
const int hurryTip = 6, hurryFrom = 35;
const double hurryOnTime = 0.7; // assumed share of hurry residents delivered in time
const int goldenFrom = 44;
const double goldenShare = 1 / 6; // assumed share of lifts that are golden
const double cap = 1.25;

enum Rating { grey, green, perfect }

class Play {
  Play(this.level, this.won, this.ratings, this.engineTripCoins);
  final int level;
  final bool won;
  final List<Rating> ratings;
  final int engineTripCoins;
}

Play playLevel(int n) {
  final level = LevelGenerator.generate(n);
  final g = LiftGame(level, recordEvents: false);
  final ratings = <Rating>[];
  void send() {
    final f = g.load / g.capacity;
    ratings.add(f >= Formulas.perfectFraction
        ? Rating.perfect
        : f >= Formulas.greenFraction
            ? Rating.green
            : Rating.grey);
    g.send();
    g.finishSend();
  }

  var steps = 0;
  while (g.phase == Phase.playing && steps++ < 20000) {
    if (blind.boardBest(g)) continue;
    if (g.riders.isNotEmpty && g.load >= Formulas.greenFraction * g.capacity) {
      send();
      continue;
    }
    if (blind.dig(g, false)) continue;
    if (g.riders.isEmpty) break;
    send();
  }
  return Play(n, g.phase == Phase.won, ratings, g.tripCoins);
}

int tripCoinsToday(List<Rating> rs, {int green = Formulas.greenTripCoins, int perfect = Formulas.perfectTripCoins}) =>
    rs.fold(0, (s, r) => s + switch (r) { Rating.grey => 0, Rating.green => green, Rating.perfect => perfect });

/// Trip coins with the combo, and the golden-lift extra (a perfect on a golden lift pays its combo coins again).
double tripCoinsV18(List<Rating> rs, int level, List<double> steps, {double scale = 1}) {
  var streak = 0;
  var total = 0.0;
  for (final r in rs) {
    if (r == Rating.grey) {
      streak = 0;
      continue;
    }
    final mult = steps[streak.clamp(0, steps.length - 1)];
    final base = (r == Rating.perfect ? Formulas.perfectTripCoins : Formulas.greenTripCoins) * scale;
    total += base * mult;
    if (r == Rating.perfect && level >= goldenFrom) total += base * mult * goldenShare;
    streak++;
  }
  return total;
}

double tipsV18(List<Rating> rs, int level) {
  if (rs.isEmpty) return 0;
  final perfectShare = rs.where((r) => r == Rating.perfect).length / rs.length;
  var t = 0.0;
  if (level >= vipFrom) t += vipTip * perfectShare; // the VIP rides one of the trips
  if (level >= hurryFrom) t += hurryTip * hurryOnTime;
  return t;
}

void main(List<String> args) {
  final from = args.isNotEmpty ? int.parse(args[0]) : 1;
  final to = args.length > 1 ? int.parse(args[1]) : Formulas.lastLevel;
  final plays = [for (var n = from; n <= to; n++) playLevel(n)];
  final won = plays.where((p) => p.won).toList();

  // Sanity: the rating rule reproduces the engine's own trip coins.
  final mismatch = won.where((p) => tripCoinsToday(p.ratings) != p.engineTripCoins).length;

  print('Coin model for PRD v1.8, levels $from-$to (blind bot, no powers)');
  print(
      'Won ${won.length} of ${plays.length}; engine trip coins reproduced on ${won.length - mismatch} of ${won.length}.');
  print('');
  print('  L    sends  grey green perf   today   v1.8(x3)  ratio');
  for (final p in won) {
    final today = Formulas.baseCoins(p.level) + tripCoinsToday(p.ratings);
    final v18 =
        Formulas.baseCoins(p.level) + tripCoinsV18(p.ratings, p.level, comboSteps) + tipsV18(p.ratings, p.level);
    int count(Rating r) => p.ratings.where((x) => x == r).length;
    print('${'${p.level}'.padLeft(3)}  ${'${p.ratings.length}'.padLeft(6)}  ${'${count(Rating.grey)}'.padLeft(4)} '
        '${'${count(Rating.green)}'.padLeft(5)} ${'${count(Rating.perfect)}'.padLeft(4)}  ${'$today'.padLeft(6)}  '
        '${v18.toStringAsFixed(0).padLeft(9)}  ${(v18 / today).toStringAsFixed(2)}');
  }

  // Bands and scenarios.
  final bands = [(1, 20), (21, 40), (41, 60), (61, 80), (81, 100), (from, to)];
  double sumToday(List<Play> ps) => ps.fold(0.0, (s, p) => s + Formulas.baseCoins(p.level) + tripCoinsToday(p.ratings));
  double sumV18(List<Play> ps, List<double> steps, {double scale = 1}) => ps.fold(
      0.0,
      (s, p) =>
          s +
          Formulas.baseCoins(p.level) +
          tripCoinsV18(p.ratings, p.level, steps, scale: scale) +
          tipsV18(p.ratings, p.level));

  print('');
  print('Per band (won levels): coins per level today, v1.8 as specced (x3), v1.8 with the cap at x2');
  for (final (a, b) in bands) {
    final ps = won.where((p) => p.level >= a && p.level <= b).toList();
    if (ps.isEmpty) continue;
    final t = sumToday(ps) / ps.length;
    final x3 = sumV18(ps, comboSteps) / ps.length;
    final x2 = sumV18(ps, comboStepsCap2) / ps.length;
    final label = a == from && b == to ? 'all' : '$a-$b';
    print('  ${label.padRight(7)}  today ${t.toStringAsFixed(1).padLeft(6)}   x3 ${x3.toStringAsFixed(1).padLeft(6)} '
        '(+${((x3 / t - 1) * 100).toStringAsFixed(0)}%)   x2 ${x2.toStringAsFixed(1).padLeft(6)} '
        '(+${((x2 / t - 1) * 100).toStringAsFixed(0)}%)');
  }

  // The trip-coin scale that holds +25% overall with the x3 cap, and what it means for the two constants.
  final total = sumToday(won);
  var lo = 0.0, hi = 1.0;
  for (var i = 0; i < 40; i++) {
    final mid = (lo + hi) / 2;
    if (sumV18(won, comboSteps, scale: mid) <= cap * total) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final green = (Formulas.greenTripCoins * lo).round(), perfect = (Formulas.perfectTripCoins * lo).round();
  print('');
  print(
      'To hold +${((cap - 1) * 100).round()}% overall with the x3 combo: scale trip coins by ${lo.toStringAsFixed(2)} '
      '(green ${Formulas.greenTripCoins} -> $green, perfect ${Formulas.perfectTripCoins} -> $perfect).');
  // Re-check with the rounded values.
  double withRounded(List<Play> ps) => ps.fold(0.0, (s, p) {
        var streak = 0;
        var trips = 0.0;
        for (final r in p.ratings) {
          if (r == Rating.grey) {
            streak = 0;
            continue;
          }
          final mult = comboSteps[streak.clamp(0, comboSteps.length - 1)];
          final base = (r == Rating.perfect ? perfect : green).toDouble();
          trips += base * mult;
          if (r == Rating.perfect && p.level >= goldenFrom) trips += base * mult * goldenShare;
          streak++;
        }
        return s + Formulas.baseCoins(p.level) + trips + tipsV18(p.ratings, p.level);
      });
  print('Check with those values: +${((withRounded(won) / total - 1) * 100).toStringAsFixed(0)}% overall.');
  print('');
  print('Assumptions: one VIP per level from $vipFrom (tips $vipTip on a perfect trip), one hurry resident per level '
      'from $hurryFrom (tips $hurryTip, ${(hurryOnTime * 100).round()}% on time), one golden lift in '
      '${(1 / goldenShare).round()} from $goldenFrom. Daily challenge (30/60/100 a day) and smooth-exit bonuses are '
      'not per-level income and are left out.');
}
