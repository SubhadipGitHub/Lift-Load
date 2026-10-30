import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/ui/layout.dart';
import 'package:lift_load/ui/widgets/cabin_floor.dart';
import 'package:lift_load/ui/widgets/lift_shaft.dart';
import 'package:lift_load/ui/widgets/resident_figure.dart';

import 'helpers.dart';

Resident r(int id, ResidentType t, [Cargo c = Cargo.none, Floor f = Floor.coral]) =>
    Resident(id: id, type: t, floor: f, cargo: c);

void main() {
  final phone = Metrics.from(const Size(390, 844));

  test('the first three riders walk to the back row, smaller; the rest stand in front', () {
    final riders = [for (var i = 0; i < 5; i++) r(i, ResidentType.officeM)];
    final spots = CabinFloor.layout(riders, phone);
    expect([for (final s in spots) s.back], [true, true, true, false, false]);
    for (final s in spots) {
      expect(s.feet, phone.cabinHeight * (s.back ? Metrics.cabinBackFeetLine : Metrics.cabinFrontFeetLine));
    }
    expect(spots.first.height, lessThan(spots.last.height));
    expect(spots.first.height, closeTo(phone.cabinFigure * Metrics.cabinBackScale, 0.01));
  });

  test('a rider keeps their spot as more board behind them', () {
    final riders = [for (var i = 0; i < 6; i++) r(i, ResidentType.values[i % 9], Cargo.waterCan)];
    for (var n = 1; n < riders.length; n++) {
      final before = CabinFloor.layout(riders.sublist(0, n), phone);
      final after = CabinFloor.layout(riders.sublist(0, n + 1), phone);
      for (var i = 0; i < n; i++) {
        expect(after[i].back, before[i].back, reason: 'rider $i keeps their row');
      }
    }
  });

  test('rule 3: spots depend on boarding order and the look, never on floor or anything hidden', () {
    final a = [r(1, ResidentType.aunty, Cargo.cylinder, Floor.coral), r(2, ResidentType.kid)];
    final b = [r(7, ResidentType.aunty, Cargo.cylinder, Floor.teal), r(9, ResidentType.kid, Cargo.none, Floor.sun)];
    final sa = CabinFloor.layout(a, phone), sb = CabinFloor.layout(b, phone);
    for (var i = 0; i < 2; i++) {
      expect((sb[i].back, sb[i].left, sb[i].feet, sb[i].height), (sa[i].back, sa[i].left, sa[i].feet, sa[i].height));
    }
  });

  test('a crowded cabin shrinks each row to fit; nothing hangs outside the cabin', () {
    for (final t in [ResidentType.pram, ResidentType.gym, ResidentType.kid]) {
      for (var n = 1; n <= 9; n++) {
        final riders = [for (var i = 0; i < n; i++) r(i, t, t.canCarry ? Cargo.suitcase : Cargo.none)];
        for (final s in CabinFloor.layout(riders, phone)) {
          expect(s.left, greaterThanOrEqualTo(0), reason: '$t x$n');
          expect(s.left + s.footprint, lessThanOrEqualTo(phone.cabinWidth + 0.01), reason: '$t x$n');
          final c = s.cargo;
          if (c != null) expect(c.left + c.width, lessThanOrEqualTo(phone.cabinWidth + 0.01), reason: '$t x$n');
          expect(s.top, greaterThan(0), reason: '$t x$n');
        }
      }
    }
  });

  test('an item is set down just in front of its owner, against their legs', () {
    final s = CabinFloor.layout([r(1, ResidentType.officeW, Cargo.waterCan)], phone).single;
    final c = s.cargo!;
    expect(c.feet, greaterThan(s.feet));
    expect(c.left, lessThan(s.left + s.personWidth), reason: 'overlaps the owner a little');
    expect(CabinFloor.layout([r(2, ResidentType.officeW)], phone).single.cargo, isNull);
  });

  testWidgets('in the cabin, riders are drawn without their item and the item stands on its own', (tester) async {
    final c = controller(DebugAnalytics(), levelFor: (_) => Level.conceptSlice());
    await pumpPlay(tester, c);
    var boarded = 0;
    for (var lane = 0; lane < c.game.laneCount && boarded < 4; lane++) {
      final front = c.game.frontOf(lane);
      if (front == null || !c.game.goesTo(front.floor)) continue;
      c.tapQueue(lane);
      c.tapLift();
      boarded++;
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final inCabin = find.descendant(of: find.byType(LiftShaft), matching: find.byType(ResidentFigure));
    expect(inCabin.evaluate().length, c.game.riders.length);
    for (final e in inCabin.evaluate()) {
      expect((e.widget as ResidentFigure).cargo, Cargo.none);
    }
    final items = c.game.riders.where((r) => r.cargo != Cargo.none).length;
    expect(find.descendant(of: find.byType(LiftShaft), matching: find.byType(CargoFigure)), findsNWidgets(items));
    expect(tester.takeException(), isNull);
  });
}
