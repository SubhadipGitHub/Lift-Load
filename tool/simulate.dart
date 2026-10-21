// Prints the level table for tuning: `dart run tool/simulate.dart [from] [to]`.
//
// Columns: level, difficulty, floors, residents, capacity, bench, solver par,
// trip budget, weight-only bound, max bench the bot used.
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/generator.dart';
import 'package:lift_load/game/solver.dart';

void main(List<String> args) {
  final from = args.isNotEmpty ? int.parse(args[0]) : 1;
  final to = args.length > 1 ? int.parse(args[1]) : 60;
  print('  L  difficulty  k   N    C  seats  par  trips  wbound  benchMax  new type');
  for (var n = from; n <= to; n++) {
    final level = LevelGenerator.generate(n);
    final result = Solver.solve(level);
    final byFloor = <Floor, int>{};
    for (final q in level.queues) {
      for (final r in q) {
        byFloor[r.floor] = (byFloor[r.floor] ?? 0) + r.kg;
      }
    }
    final wb = Formulas.weightBoundTrips(byFloor, level.capacity);
    final debut = ResidentType.introducedAt(n)?.name ?? '';
    print('${'$n'.padLeft(3)}  ${level.difficulty.name.padRight(10)}'
        '${'${level.floors.length}'.padLeft(2)}'
        '${'${level.residentCount}'.padLeft(4)}'
        '${'${level.capacity}'.padLeft(5)}'
        '${'${level.benchSize}'.padLeft(6)}'
        '${'${level.parTrips}'.padLeft(5)}'
        '${'${level.trips}'.padLeft(7)}'
        '${'$wb'.padLeft(8)}'
        '${'${result.maxBenchUsed}'.padLeft(10)}  $debut');
  }
}
