import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/formulas.dart';
import 'package:lift_load/game/level.dart';
import 'package:lift_load/game/powers.dart';
import 'package:lift_load/game/scenario.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/ui/art_assets.dart';
import 'package:lift_load/ui/layout.dart';
import 'package:lift_load/ui/painters/gauge_painter.dart';
import 'package:lift_load/ui/screens/play_screen.dart';
import 'package:lift_load/ui/theme.dart';
import 'package:lift_load/ui/widgets/art_icon.dart';
import 'package:lift_load/ui/widgets/glossy.dart';
import 'package:lift_load/ui/widgets/load_gauge.dart';
import 'package:lift_load/ui/widgets/play_bar.dart';
import 'package:lift_load/ui/widgets/resident_figure.dart';

import 'helpers.dart';

/// A bundle that serves every asset but [missing].
class _MissingBundle extends CachingAssetBundle {
  _MissingBundle(this.missing);

  final String missing;

  @override
  Future<ByteData> load(String key) => key == missing ? Future.error(FlutterError('no $key')) : rootBundle.load(key);
}

/// The painter of the face of the glossy button found by [button].
GlossyPainter facePainter(WidgetTester tester, Finder button) => tester
    .widgetList<CustomPaint>(find.descendant(of: button, matching: find.byType(CustomPaint)))
    .map((p) => p.painter)
    .whereType<GlossyPainter>()
    .first;

void main() {
  setUp(() async {
    SpriteCache.instance.debugReset();
    await SpriteCache.instance.load();
  });

  group('icons', () {
    test('every icon in the table ships, decodes, and is a 256 px square', () {
      expect(SpriteCache.instance.failed, isEmpty);
      for (final i in GameIcon.values) {
        final image = SpriteCache.instance.icon(i);
        expect(image, isNotNull, reason: i.name);
        expect((image!.width, image.height), (256, 256), reason: i.name);
      }
      for (final k in LiftKind.values) {
        expect(SpriteCache.instance.kindIcon(k) == null, k == LiftKind.normal, reason: k.name);
      }
      for (final s in Scenario.values) {
        expect(SpriteCache.instance.scenarioIcon(s), isNotNull, reason: s.name);
      }
    });

    test('assets/art holds exactly the table: no power-cut scene, no floor badges', () {
      final shipped = Directory('assets/art').listSync().map((f) => f.uri.pathSegments.last).toSet();
      expect(shipped, ArtAssets.all.map((p) => p.split('/').last).toSet());
      final icons = shipped.where((f) => f.startsWith('icon_')).toSet();
      expect(icons, ArtAssets.icons.map((p) => p.split('/').last).toSet());
      expect(icons, isNot(contains('icon_scene_powercut.webp')));
      // The floor badges are the floor's own colour: on a floor-coloured tag
      // they vanish, so tags keep the painted white glyph and the art stays out.
      expect(icons.where((f) => f.startsWith('icon_floor_')), isEmpty);
      // Every approved icon but those is shipped.
      final approved = Directory('docs/art/approved')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .where((f) => f.startsWith('icon_') && !f.startsWith('icon_floor_') && f != 'icon_scene_powercut.webp')
          .toSet();
      expect(icons, approved);
    });

    Widget icons({required bool sprites}) => app(SpriteArtScope(
          enabled: sprites,
          child: Center(
            child: Wrap(children: [
              for (final i in GameIcon.values) ArtIcon(i, size: 24),
              for (final k in LiftKind.values.where((k) => k != LiftKind.normal)) ArtIcon.kind(k, size: 24),
              for (final s in Scenario.values) ArtIcon.scenario(s, size: 24),
            ]),
          ),
        ));

    int iconCount() => GameIcon.values.length + LiftKind.values.length - 1 + Scenario.values.length;

    testWidgets('with art on every icon draws its image at its size', (tester) async {
      await tester.pumpWidget(icons(sprites: true));
      expect(find.byType(RawImage), findsNWidgets(iconCount()));
      expect(find.descendant(of: find.byType(ArtIcon), matching: find.byType(Icon)), findsNothing);
      final heart = tester.widget<RawImage>(find.descendant(of: find.byType(ArtIcon).first, matching: find.byType(RawImage)));
      expect(heart.image, same(SpriteCache.instance.icon(GameIcon.heart)));
      for (final e in find.byType(ArtIcon).evaluate()) {
        expect(tester.getSize(find.byWidget(e.widget)), const Size(24, 24));
      }
    });

    testWidgets('with the switch off every icon falls back to its Material icon', (tester) async {
      await tester.pumpWidget(icons(sprites: false));
      expect(find.byType(RawImage), findsNothing);
      final fallbacks = tester.widgetList<Icon>(find.descendant(of: find.byType(ArtIcon), matching: find.byType(Icon)));
      expect(fallbacks, hasLength(iconCount()));
      expect(fallbacks.first.icon, ArtIcon.fallbackOf(GameIcon.heart));
      expect(fallbacks.first.color, LL.alarm);
    });

    testWidgets('an icon that fails to load falls back alone', (tester) async {
      SpriteCache.instance.debugReset();
      await tester.runAsync(() => SpriteCache.instance.load(bundle: _MissingBundle(ArtAssets.icon(GameIcon.coin))));
      expect(SpriteCache.instance.failed, {ArtAssets.icon(GameIcon.coin)});
      await tester.pumpWidget(app(Row(children: [
        ArtIcon(GameIcon.coin, size: 24),
        ArtIcon(GameIcon.heart, size: 24),
      ])));
      expect(find.descendant(of: find.byType(ArtIcon).at(0), matching: find.byIcon(Icons.monetization_on_rounded)),
          findsOneWidget);
      expect(find.descendant(of: find.byType(ArtIcon).at(1), matching: find.byType(RawImage)), findsOneWidget);
    });

    testWidgets('the play screen uses no approved icon with the switch off', (tester) async {
      final c = powerController(DebugAnalytics(), level: dockLevel(number: 73));
      c.startLevel();
      await tester.pumpWidget(app(SpriteArtScope(enabled: false, child: PlayScreen(controller: c))));
      expect(find.byType(ArtIcon), findsWidgets);
      expect(find.byType(RawImage), findsNothing);
      await tester.pumpWidget(app(PlayScreen(controller: c)));
      expect(find.descendant(of: find.byType(ArtIcon), matching: find.byType(RawImage)), findsWidgets);
    });
  });

  group('surfaces', () {
    testWidgets('Send is the mint glossy surface, and slate while it cannot send', (tester) async {
      final c = controller(DebugAnalytics(), levelFor: (_) => Level.conceptSlice());
      await pumpPlay(tester, c);
      final send = find.byKey(SendButton.buttonKey);
      // Nobody aboard: disabled, flat slate with no gloss, and a tap does nothing.
      expect(tester.widget<GlossyButton>(send).onPressed, isNull);
      final off = facePainter(tester, send);
      expect(off.style, SurfaceStyle.off);
      expect(off.style.gloss, 0);
      await tester.tap(send);
      await tester.pump();
      expect(c.game.tripsUsed, 0);
      // Someone aboard: mint, glossy, and it sends.
      c.tapQueue(0);
      c.tapLift();
      await tester.pump();
      final on = facePainter(tester, send);
      expect(on.style, SurfaceStyle.mint);
      expect(on.style.mid, LL.mint);
      expect(on.style.gloss, greaterThan(0));
      expect(on.style.mid, isNot(off.style.mid));
      expect(on.style.edge, isNot(off.style.edge));
      expect(find.descendant(of: send, matching: find.text('Send')), findsOneWidget);
      expect(
        find.descendant(
            of: send, matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SendGlyphPainter)),
        findsOneWidget,
      );
      await tester.tap(send);
      await tester.pump();
      expect(c.game.tripsUsed, 1);
    });

    testWidgets('a glossy button sinks onto its edge while pressed, and not under reduced motion', (tester) async {
      for (final animate in [true, false]) {
        await tester.pumpWidget(app(
          Center(
            child: GlossyButton(
              key: const ValueKey('b'),
              style: SurfaceStyle.cream,
              onPressed: () {},
              width: 160,
              height: 60,
              child: const Text('Press'),
            ),
          ),
          animate: animate,
        ));
        final button = find.byKey(const ValueKey('b'));
        final rest = tester.getTopLeft(find.text('Press')).dy;
        expect(facePainter(tester, button).press, 0);
        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final m = Metrics.from(tester.view.physicalSize / tester.view.devicePixelRatio);
        final travel = m.surface(SurfaceDepth.button).press;
        if (animate) {
          expect(facePainter(tester, button).press, 1);
          expect(tester.getTopLeft(find.text('Press')).dy, closeTo(rest + travel, 0.01));
        } else {
          expect(facePainter(tester, button).press, 0);
          expect(tester.getTopLeft(find.text('Press')).dy, rest);
        }
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(facePainter(tester, button).press, 0);
        await tester.pumpWidget(const SizedBox());
      }
    });

    test('an inset face stays inside its box, pressed or not, and a pill face is round-ended', () {
      final m = Metrics.from(const Size(390, 844));
      for (final depth in SurfaceDepth.values) {
        final s = m.surface(depth);
        for (final press in [0.0, 0.5, 1.0]) {
          const box = Size(118, 62);
          final face = GlossyPainter.faceRect(box, s, press, inset: true);
          final edge = s.edge - s.press * press;
          final drop = s.drop * (1 - press / 2);
          expect(face.top - s.outline, greaterThanOrEqualTo(-1e-9));
          expect(face.bottom + s.outline + edge + drop, lessThanOrEqualTo(box.height + 1e-9), reason: '$depth $press');
          expect(face.left, s.outline);
        }
        expect(GlossyPainter.faceRect(const Size(40, 20), s, 0, inset: false), Offset.zero & const Size(40, 20));
      }
    });

    testWidgets('floor tags, NEXT chips and seats are glossy in their floor colours', (tester) async {
      final c = controller(DebugAnalytics(), levelFor: (_) => Level.conceptSlice());
      await pumpPlay(tester, c);
      c.tapQueue(0);
      c.tapBench(0);
      await tester.pump();
      final styles = {
        for (final p in tester.widgetList<CustomPaint>(find.byType(CustomPaint)).map((p) => p.painter))
          if (p is GlossyPainter) p.style,
      };
      for (final f in c.game.level.floors) {
        expect(styles, contains(SurfaceStyle.floor(f)), reason: f.name);
      }
      expect(styles, contains(SurfaceStyle.seat));
      expect(styles, contains(SurfaceStyle.chip), reason: 'HUD pills');
      expect(styles, contains(SurfaceStyle.brass), reason: 'level pill');
      expect(styles, contains(SurfaceStyle.plum), reason: 'back and settings');
      expect(styles, contains(SurfaceStyle.cream), reason: 'Scale');
    });
  });

  testWidgets('a power used up for this level shows the lock; one with stock does not', (tester) async {
    final c = powerController(DebugAnalytics(), stock: {Power.trip: Formulas.powerCap(Power.trip) + 1});
    await pumpPlay(tester, c);
    Finder lock(Power p) => find.descendant(
        of: find.byKey(ValueKey('power-${p.name}')),
        matching: find.byWidgetPredicate((w) => w is ArtIcon && w.path == ArtAssets.icon(GameIcon.lock)));
    expect(lock(Power.trip), findsNothing);
    for (var i = 0; i < Formulas.powerCap(Power.trip); i++) {
      c.usePower(Power.trip);
    }
    await tester.pump();
    expect(c.powerStock(Power.trip), greaterThan(0), reason: 'stock left, but capped');
    expect(lock(Power.trip), findsOneWidget);
    expect(lock(Power.seats), findsNothing);
  });

  group('gauge glow', () {
    test('it glows only in the green and red, never in the grey', () {
      expect(LoadGauge.glowFor(LoadZone.empty), 0);
      expect(LoadGauge.glowFor(LoadZone.light), 0);
      expect(LoadGauge.glowFor(LoadZone.green), greaterThan(0));
      expect(LoadGauge.glowFor(LoadZone.limit), greaterThan(LoadGauge.glowFor(LoadZone.green)));
      expect(LoadGauge.glowFor(LoadZone.overload), 1);
      expect(GaugePainter.glowArc(over: false), (0.75, 1.0));
      expect(GaugePainter.glowArc(over: true), (1.0, GaugePainter.span));
    });

    testWidgets('the Scale ghost moves only its dashed needle, never the glow', (tester) async {
      GaugePainter painter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<GaugePainter>()
          .single;
      for (final zone in LoadZone.values) {
        await tester.pumpWidget(app(Center(child: LoadGauge(fraction: 0.5, zone: zone))));
        final without = painter();
        for (final ghost in [0.2, 0.9, 1.1]) {
          await tester.pumpWidget(app(Center(child: LoadGauge(fraction: 0.5, zone: zone, ghost: ghost))));
          final withGhost = painter();
          expect(withGhost.ghost, ghost);
          expect((withGhost.glow, withGhost.glowColor, withGhost.over),
              (without.glow, without.glowColor, without.over), reason: '$zone ghost $ghost');
        }
      }
    });
  });
}
