import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/ui/art_assets.dart';
import 'package:lift_load/ui/layout.dart';
import 'package:lift_load/ui/painters/resident_painter.dart';
import 'package:lift_load/ui/painters/sprite_painter.dart';
import 'package:lift_load/ui/theme.dart';
import 'package:lift_load/ui/widgets/lift_shaft.dart';
import 'package:lift_load/ui/widgets/resident_figure.dart';

import 'helpers.dart';

/// Every pair a level can hold: carriers with each prop, the rest bare.
final pairs = [
  for (final t in ResidentType.values)
    for (final c in Cargo.values)
      if (t.canCarry || c == Cargo.none) (t, c),
];

CustomPainter? painterOf(WidgetTester tester, Finder figure) => tester
    .widget<CustomPaint>(find.descendant(of: figure, matching: find.byType(CustomPaint)).first)
    .painter;

Widget figures(List<Widget> children, {bool sprites = true}) => app(
      SpriteArtScope(
        enabled: sprites,
        child: Center(child: Wrap(children: children)),
      ),
    );

/// The contact shadow: a warm near-black oval.
bool isShadow(Symbol method, List<dynamic> args) =>
    method == #drawOval && (args[1] as Paint).color.toARGB32() == LL.contactShadow.toARGB32();

/// A bundle that serves every asset but [missing].
class _MissingBundle extends CachingAssetBundle {
  _MissingBundle(this.missing);

  final String missing;

  @override
  Future<ByteData> load(String key) =>
      key == missing ? Future.error(FlutterError('no $key')) : rootBundle.load(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SpriteCache.instance.debugReset();
    await SpriteCache.instance.load();
  });

  test('every sprite in the table ships, is declared and decodes', () {
    expect(SpriteCache.instance.failed, isEmpty);
    expect(SpriteCache.instance.loaded, isTrue);
    for (final t in ResidentType.values) {
      expect(SpriteCache.instance.resident(t), isNotNull, reason: t.name);
    }
    for (final c in Cargo.values.where((c) => c != Cargo.none)) {
      expect(SpriteCache.instance.cargo(c), isNotNull, reason: c.name);
    }
    expect(SpriteCache.instance.ghost, isNotNull);
    // Nothing extra ships (the power-cut scene left with its scenario).
    final shipped = Directory('assets/art').listSync().map((f) => f.uri.pathSegments.last).toSet();
    expect(shipped, ArtAssets.all.map((p) => p.split('/').last).toSet());
  });

  test('each sprite stands inside its figure box, feet on the feet line', () {
    for (final (t, c) in pairs) {
      final person = SpriteCache.instance.resident(t)!;
      final painter = SpriteFigurePainter(
        person: person,
        cargo: SpriteCache.instance.cargo(c),
        designWidth: ResidentLook.designWidth(t, c),
      );
      final size = Size(ResidentLook.designWidth(t, c), designHeight);
      final body = painter.personRect(size);
      final reason = '${t.name} ${c.name}';
      expect(body.bottom, feetY, reason: reason);
      expect(body.top, greaterThan(0), reason: reason);
      expect(body.left, greaterThanOrEqualTo(0), reason: reason);
      final prop = painter.cargoRect(size);
      expect(prop == null, c == Cargo.none, reason: reason);
      if (prop != null) {
        expect(prop.right, closeTo(size.width, 1e-9), reason: reason);
        expect(prop.bottom, feetY, reason: reason);
        // Beside the person, not in front of them.
        expect(prop.left, greaterThanOrEqualTo(body.right - 1), reason: reason);
      } else {
        expect(body.right, lessThanOrEqualTo(size.width), reason: reason);
      }
    }
  });

  testWidgets('every type and cargo draws as a sprite with a contact shadow', (tester) async {
    await tester.pumpWidget(figures([for (final (t, c) in pairs) ResidentFigure(type: t, cargo: c, height: 86)]));
    final found = find.byType(ResidentFigure);
    expect(found, findsNWidgets(pairs.length));
    for (var i = 0; i < pairs.length; i++) {
      final (t, c) = pairs[i];
      final figure = found.at(i);
      final painter = painterOf(tester, figure);
      expect(painter, isA<SpriteFigurePainter>(), reason: '${t.name} ${c.name}');
      // Same box as the painter, so switching never moves a layout.
      expect(tester.getSize(figure).width, closeTo(86 / designHeight * ResidentLook.designWidth(t, c), 1e-6));
      final paint = find.descendant(of: figure, matching: find.byType(CustomPaint)).first;
      expect(
        tester.renderObject(paint),
        c == Cargo.none
            ? (paints
              ..something(isShadow)
              ..drawImageRect(image: SpriteCache.instance.resident(t)))
            : (paints
              ..something(isShadow)
              ..something(isShadow)
              ..drawImageRect(image: SpriteCache.instance.resident(t))
              ..drawImageRect(image: SpriteCache.instance.cargo(c))),
        reason: '${t.name} ${c.name}',
      );
    }
  });

  test('the contact shadow is 0.62 of the sprite wide, 0.20 of that tall, on the feet', () {
    const sprite = Rect.fromLTWH(10, 20, 50, 96);
    final shadow = SpriteFigurePainter.shadowRect(sprite);
    expect(shadow.center, sprite.bottomCenter);
    expect(shadow.width, closeTo(50 * 0.62, 1e-9));
    expect(shadow.height, closeTo(50 * 0.62 * 0.20, 1e-9));
  });

  testWidgets('with the switch off the painter draws every figure', (tester) async {
    await tester.pumpWidget(figures(
      [for (final (t, c) in pairs) ResidentFigure(type: t, cargo: c, height: 86), ResidentFigure.unknown(height: 86)],
      sprites: false,
    ));
    for (final e in find.byType(ResidentFigure).evaluate()) {
      expect(painterOf(tester, find.byWidget(e.widget)), isA<ResidentPainter>());
    }
  });

  testWidgets('a sprite that fails to load falls back to the painter for that figure only', (tester) async {
    SpriteCache.instance.debugReset();
    await tester.runAsync(
        () => SpriteCache.instance.load(bundle: _MissingBundle(ArtAssets.resident(ResidentType.uncle))));
    expect(SpriteCache.instance.failed, {ArtAssets.resident(ResidentType.uncle)});
    await tester.pumpWidget(figures([
      const ResidentFigure(type: ResidentType.uncle, height: 86),
      const ResidentFigure(type: ResidentType.aunty, height: 86),
    ]));
    expect(painterOf(tester, find.byType(ResidentFigure).at(0)), isA<ResidentPainter>());
    expect(painterOf(tester, find.byType(ResidentFigure).at(1)), isA<SpriteFigurePainter>());
  });

  testWidgets('before the sprites load the painter shows, then the sprite swaps in', (tester) async {
    SpriteCache.instance.debugReset();
    await tester.pumpWidget(figures([const ResidentFigure(type: ResidentType.gym, height: 86)]));
    expect(painterOf(tester, find.byType(ResidentFigure)), isA<ResidentPainter>());
    await tester.runAsync(() => SpriteCache.instance.load());
    await tester.pump();
    expect(painterOf(tester, find.byType(ResidentFigure)), isA<SpriteFigurePainter>());
  });

  testWidgets('the unknown ghost is one sprite, one size, for everyone in the lobby', (tester) async {
    final c = controller(DebugAnalytics(), levelFor: (_) => dockLevel(lanes: 5));
    await pumpPlay(tester, c);
    await tester.pump();
    final ghosts = find.byWidgetPredicate((w) => w is ResidentFigure && w.dimmed);
    expect(ghosts, findsWidgets);
    final sizes = {for (final e in ghosts.evaluate()) tester.getSize(find.byWidget(e.widget))};
    expect(sizes, hasLength(1));
    for (final e in ghosts.evaluate()) {
      final painter = painterOf(tester, find.byWidget(e.widget));
      expect(painter, isA<SpriteFigurePainter>());
      painter as SpriteFigurePainter;
      expect(painter.ghost, isTrue);
      expect(painter.person, same(SpriteCache.instance.ghost));
      expect(painter.cargo, isNull);
      expect(painter.designWidth, personWidth);
    }
  });

  testWidgets('the first rider stands on the back row of the cabin floor', (tester) async {
    final c = controller(DebugAnalytics(), levelFor: (_) => Level.conceptSlice());
    await pumpPlay(tester, c);
    c.tapQueue(0);
    c.tapLift();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final cabin = tester.getRect(find.bySemanticsLabel(RegExp('Tap to board the selected resident')));
    final rider = find.descendant(of: find.byType(LiftShaft), matching: find.byType(ResidentFigure)).first;
    final box = tester.getRect(rider);
    final feet = box.bottom - box.height * ResidentFigure.belowFeet;
    // The first rider walks to the back row.
    expect(feet, closeTo(cabin.top + cabin.height * Metrics.cabinBackFeetLine, 0.5));
    expect(painterOf(tester, rider), isA<SpriteFigurePainter>());
  });

  test('figures are 60% larger at the design size', () {
    final m = Metrics.from(const Size(390, 844));
    expect(m.cabinFigure, 128);
    expect(m.laneFigureFor(4), 86);
    expect(m.laneFigureFor(3), 86);
    expect(m.benchFigureFor(4), closeTo(86 * Metrics.benchToLane, 0.01));
  });
}
