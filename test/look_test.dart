import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/ui/painters/resident_painter.dart';

void main() {
  test('a power-cut shadow is the same size for everyone', () {
    for (final t in ResidentType.values) {
      for (final c in Cargo.values) {
        expect(ResidentLook.designWidth(t, c, dimmed: true), personWidth, reason: '${t.name} ${c.name}');
      }
    }
  });

  test('vehicles and cargo widen the figure so props never overlap the next lane', () {
    expect(ResidentLook.designWidth(ResidentType.uncle, Cargo.none), personWidth);
    expect(ResidentLook.designWidth(ResidentType.uncle, Cargo.cylinder), personWidth + cargoWidth);
    expect(ResidentLook.designWidth(ResidentType.bellhop, Cargo.none), personWidth + vehicleWidth);
    expect(ResidentLook.designWidth(ResidentType.pram, Cargo.none), personWidth + vehicleWidth);
    expect(ResidentLook.designWidth(ResidentType.wheelchair, Cargo.none), personWidth);
  });
}
