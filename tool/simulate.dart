// Prints the level table for tuning: `dart run tool/simulate.dart [from] [to]`.
//
// Columns: level, difficulty, floors, residents, capacity, bench, solver par,
// trip budget, weight-only bound, max bench the bot used, cargo carriers,
// venue, lift pattern (n normal, o old, s service, e express), scenario,
// and what debuts on the level.
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/debuts.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/generator.dart';
import 'package:lift_load/game/solver.dart';

void main(List<String> args) {
  final from = args.isNotEmpty ? int.parse(args[0]) : 1;
  final to = args.length > 1 ? int.parse(args[1]) : Formulas.lastLevel;
  print('  L  difficulty  k   N    C  seats  par  trips  wbound  benchMax  cargo  venue     lifts  scenario     debut');
  for (var n = from; n <= to; n++) {
    final level = LevelGenerator.generate(n);
    final result = Solver.solve(level);
    final everyone = [
      for (final q in level.queues) ...q,
      for (final a in level.arrivals) a.resident,
    ];
    final byFloor = <Floor, int>{};
    for (final r in everyone) {
      byFloor[r.floor] = (byFloor[r.floor] ?? 0) + r.kg;
    }
    final wb = Formulas.weightBoundTrips(byFloor, level.capacity);
    final cargo = everyone.where((r) => r.cargo != Cargo.none).length;
    final lifts = level.liftSchedule.map((k) => k.name[0]).join();
    print('${'$n'.padLeft(3)}  ${level.difficulty.name.padRight(10)}'
        '${'${level.floors.length}'.padLeft(2)}'
        '${'${level.residentCount}'.padLeft(4)}'
        '${'${level.capacity}'.padLeft(5)}'
        '${'${level.benchSize}'.padLeft(6)}'
        '${'${level.parTrips}'.padLeft(5)}'
        '${'${level.trips}'.padLeft(7)}'
        '${'$wb'.padLeft(8)}'
        '${'${result.maxBenchUsed}'.padLeft(10)}'
        '${'$cargo'.padLeft(7)}  '
        '${level.venue.name.padRight(10)}'
        '${lifts.padRight(7)}'
        '${(level.scenario?.name ?? '').padRight(13)}'
        '${Debut.at(n)?.name ?? ''}');
  }
}
