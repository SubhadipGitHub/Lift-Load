import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/game/cast.dart';
import 'package:lift_load/game/engine.dart';
import 'package:lift_load/game/powers.dart';
import 'package:lift_load/game/scenario.dart';
import 'package:lift_load/game/venue.dart';
import 'package:lift_load/services/analytics_service.dart';
import 'package:lift_load/ui/art_assets.dart';
import 'package:lift_load/ui/game_controller.dart';
import 'package:lift_load/ui/layout.dart';
import 'package:lift_load/ui/screens/play_screen.dart';
import 'package:lift_load/ui/theme.dart';
import 'package:lift_load/ui/widgets/glossy.dart';
import 'package:lift_load/ui/widgets/lane_scroller.dart';
import 'package:lift_load/ui/widgets/lift_shaft.dart';
import 'package:lift_load/ui/widgets/lobby.dart';
import 'package:lift_load/ui/widgets/play_bar.dart';
import 'package:lift_load/ui/widgets/resident_figure.dart';

import 'helpers.dart';

/// Polish pass, slice A: the lanes scroll with every pointer, they get more
/// of the screen, floors are told apart by colour and label (no shape glyph),
/// and the lift here shows its floors once.

/// The lane area's height at each size in the 14-size sweep, before this
/// pass (textScale 1; the area does not depend on the lane count).
const lanesBefore = {
  'phone 320x568': (Size(320, 568), 117.7),
  'phone 360x640': (Size(360, 640), 189.7),
  'phone 375x667': (Size(375, 667), 213.1),
  'phone 390x844': (Size(390, 844), 300.8),
  'phone 412x915': (Size(412, 915), 341.3),
  'phone 430x932': (Size(430, 932), 334.1),
  'phone landscape 844x390': (Size(844, 390), 374.4),
  'tablet 600x960': (Size(600, 960), 312.1),
  'tablet 768x1024': (Size(768, 1024), 334.2),
  'tablet 820x1180': (Size(820, 1180), 394.9),
  'tablet 1024x1366': (Size(1024, 1366), 565.2),
  'tablet landscape 1024x768': (Size(1024, 768), 739.0),
  'tablet landscape 1180x820': (Size(1180, 820), 787.2),
  'tablet landscape 1366x1024': (Size(1366, 1024), 988.0),
};

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<GameController> _play(WidgetTester tester, {Size size = const Size(390, 844), int lanes = 4}) async {
  _size(tester, size);
  final c = powerController(DebugAnalytics(), level: dockLevel(lanes: lanes), stock: {Power.swap: 1});
  c.startLevel();
  await tester.pumpWidget(app(PlayScreen(controller: c)));
  return c;
}

Finder get _scroll => find.byKey(LaneScroller.scrollKey);

ScrollableState _scrollable(WidgetTester tester) =>
    tester.state<ScrollableState>(find.descendant(of: _scroll, matching: find.byType(Scrollable)));

double _fade(WidgetTester tester, Key key) => tester
    .widget<AnimatedOpacity>(find.descendant(of: find.byKey(key), matching: find.byType(AnimatedOpacity)))
    .opacity;

/// The first resident standing at a lane front.
Finder get _front => find.descendant(of: find.byType(QueueLanes), matching: find.byType(ResidentFigure)).first;

/// A private widget, by its class name.
Finder _byType(String name) => find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

String _plain(WidgetTester tester, Finder within) =>
    tester.widget<RichText>(find.descendant(of: within, matching: find.byType(RichText)).first).text.toPlainText();

void main() {
  setUpAll(() => SpriteCache.instance.load());

  group('the queue scrolls', () {
    test('every pointer may drag it, with a soft bounce that always scrolls', () {
      const behavior = PlayScrollBehavior();
      expect(
        behavior.dragDevices,
        containsAll([
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        ]),
      );
      final physics = behavior.getScrollPhysics(_FakeContext());
      expect(physics, isA<AlwaysScrollableScrollPhysics>());
      expect(physics.parent, isA<BouncingScrollPhysics>());
    });

    for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.stylus]) {
      testWidgets('a ${kind.name} drag scrolls the lanes, and back', (tester) async {
        await _play(tester);
        final state = _scrollable(tester);
        expect(state.position.maxScrollExtent, greaterThan(0), reason: 'the lanes are taller than their area');
        expect(state.position.pixels, 0);
        await tester.drag(_scroll, const Offset(0, -140), kind: kind);
        await tester.pumpAndSettle();
        expect(state.position.pixels, greaterThan(state.position.maxScrollExtent / 2), reason: kind.name);
        final scrolled = state.position.pixels;
        await tester.drag(_scroll, const Offset(0, 60), kind: kind);
        await tester.pumpAndSettle();
        expect(state.position.pixels, lessThan(scrolled), reason: kind.name);
      });
    }

    testWidgets('the mouse wheel and a trackpad scroll it', (tester) async {
      await _play(tester);
      final state = _scrollable(tester);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(tester.getCenter(_scroll)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
      await tester.pumpAndSettle();
      expect(state.position.pixels, greaterThan(0), reason: 'wheel');
      state.position.jumpTo(0);
      await tester.pump();
      final pad = TestPointer(2, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pad.panZoomStart(tester.getCenter(_scroll)));
      await tester.sendEventToBinding(pad.panZoomUpdate(tester.getCenter(_scroll), pan: const Offset(0, -80)));
      await tester.sendEventToBinding(pad.panZoomEnd());
      await tester.pumpAndSettle();
      expect(state.position.pixels, greaterThan(0), reason: 'trackpad');
    });

    for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
      testWidgets('a ${kind.name} tap on a front still selects; a drag from one does not', (tester) async {
        final c = await _play(tester);
        // A drag that starts on a lane front scrolls and selects nobody.
        final gesture = await tester.startGesture(tester.getCenter(_front), kind: kind);
        for (var i = 0; i < 6; i++) {
          await gesture.moveBy(const Offset(0, -24));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(_scrollable(tester).position.pixels, greaterThan(0), reason: 'the drag scrolled');
        expect(c.game.selection, isNull, reason: 'the drag selected nobody');
        // Back at the top, a tap selects.
        _scrollable(tester).position.jumpTo(0);
        await tester.pump();
        await tester.tapAt(tester.getCenter(_front), kind: kind);
        await tester.pump();
        expect(c.game.selection, Selection.queue(0), reason: '${kind.name} tap');
      });
    }

    testWidgets('a thin bar and an edge fade show where more lies, and go when it does not', (tester) async {
      await _play(tester);
      await tester.pumpAndSettle();
      expect(find.byType(RawScrollbar), findsOneWidget);
      expect(tester.widget<RawScrollbar>(find.byType(RawScrollbar)).thumbVisibility, isTrue);
      expect(_fade(tester, LaneScroller.fadeBottomKey), 1, reason: 'more below at the top');
      expect(_fade(tester, LaneScroller.fadeTopKey), 0, reason: 'nothing above at the top');
      final state = _scrollable(tester);
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(_fade(tester, LaneScroller.fadeBottomKey), 0, reason: 'nothing below at the end');
      expect(_fade(tester, LaneScroller.fadeTopKey), 1, reason: 'more above at the end');
    });

    testWidgets('a lobby that fits has no fade', (tester) async {
      _size(tester, const Size(1366, 1024));
      final c = powerController(DebugAnalytics(), level: dockLevel(lanes: 3));
      c.startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c)));
      await tester.pumpAndSettle();
      expect(_scrollable(tester).position.maxScrollExtent, 0);
      expect(_fade(tester, LaneScroller.fadeBottomKey), 0);
      expect(_fade(tester, LaneScroller.fadeTopKey), 0);
    });

    testWidgets('scrolling never reveals more people: each lane still draws at most visibleDepth', (tester) async {
      final c = await _play(tester);
      final depth = Metrics.from(const Size(390, 844)).visibleDepth;
      int drawn() =>
          find.descendant(of: find.byType(QueueLanes), matching: find.byType(ResidentFigure)).evaluate().length;
      expect(drawn(), lessThanOrEqualTo(c.game.laneCount * depth));
      final state = _scrollable(tester);
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(drawn(), lessThanOrEqualTo(c.game.laneCount * depth));
      // The end of the scroll is the end of the drawn lanes: no counter, no "more".
      expect(find.textContaining(RegExp('more|waiting', caseSensitive: false)), findsNothing);
    });
  });

  group('the lanes get more of the screen', () {
    testWidgets('at 390x844 the lane area is at least 45% of the screen', (tester) async {
      _size(tester, const Size(390, 844));
      final c = powerController(DebugAnalytics(), level: dockLevel(), stock: {Power.swap: 1});
      c.startLevel();
      await tester.pumpWidget(app(PlayScreen(controller: c)));
      final area = tester.getSize(find.byType(LobbyFloor)).height;
      expect(area / 844, greaterThanOrEqualTo(0.45), reason: 'lane area $area of 844');
    });

    for (final MapEntry(key: name, value: (size, before)) in lanesBefore.entries) {
      testWidgets('the lane area at $name is not smaller than it was', (tester) async {
        _size(tester, size);
        final c = powerController(DebugAnalytics(), level: dockLevel(), stock: {Power.swap: 1});
        c.startLevel();
        await tester.pumpWidget(app(PlayScreen(controller: c)));
        expect(tester.takeException(), isNull);
        final area = tester.getSize(find.byType(LobbyFloor)).height;
        expect(area, greaterThanOrEqualTo(before - 0.5), reason: '$name: $area, was $before');
      });
    }

    testWidgets('seating someone never moves the lanes: every seat keeps one height', (tester) async {
      final c = await _play(tester);
      final before = tester.getRect(find.byType(LobbyFloor));
      final empty = tester.getSize(_byType('_Seat').first).height;
      c.tapQueue(0);
      c.tapBench(0);
      await tester.pump();
      expect(c.game.benchUsed, 1);
      expect(tester.getSize(_byType('_Seat').first).height, empty);
      expect(tester.getRect(find.byType(LobbyFloor)), before);
      expect(empty, greaterThanOrEqualTo(Metrics.minTouch));
    });
  });

  group('one gutter and one set of radii', () {
    for (final size in const [Size(320, 568), Size(390, 844), Size(412, 915), Size(768, 1024), Size(1024, 1366)]) {
      for (final left in [false, true]) {
        testWidgets('HUD, shaft, bench, lobby floor and bottom bar share their edges at $size, left-handed $left',
            (tester) async {
          _size(tester, size);
          final c = powerController(DebugAnalytics(), level: dockLevel(), stock: {Power.swap: 1, Power.seats: 1});
          c.profile.leftHanded = left;
          c.startLevel();
          await tester.pumpWidget(app(PlayScreen(controller: c)));
          Rect face(Finder f) => tester.getRect(find.descendant(of: f, matching: find.byType(Glossy)).first);
          // The shaft panel is the first decorated box inside the LiftShaft.
          final panel =
              tester.getRect(find.descendant(of: find.byType(LiftShaft), matching: find.byType(DecoratedBox)).first);
          const tol = 1.0;
          expect(face(find.byTooltip('Back to the tower')).left, closeTo(panel.left, tol), reason: 'back');
          expect(face(find.byTooltip('Settings')).right, closeTo(panel.right, tol), reason: 'settings');
          final seats = _byType('_Seat');
          expect(tester.getRect(seats.first).left, closeTo(panel.left, tol), reason: 'first seat');
          expect(tester.getRect(seats.last).right, closeTo(panel.right, tol), reason: 'last seat');
          final floor =
              tester.getRect(find.descendant(of: find.byType(QueueLanes), matching: find.byType(DecoratedBox)).first);
          expect(floor.left, closeTo(panel.left, tol), reason: 'lobby floor');
          expect(floor.right, closeTo(panel.right, tol), reason: 'lobby floor');
          final send = tester.getRect(find.byKey(SendButton.buttonKey));
          if (left) {
            expect(send.left, closeTo(panel.left, tol), reason: 'send, left-handed');
          } else {
            expect(send.right, closeTo(panel.right, tol), reason: 'send');
          }
          // Send and the dock buttons share a top and a bottom edge.
          final button = face(find.byKey(const ValueKey('power-swap')));
          expect(send.top, closeTo(button.top, tol), reason: 'Send top');
          expect(send.bottom, closeTo(button.bottom, tol), reason: 'Send bottom');
        });
      }
    }

    test('panels share one radius, and everything inside them another', () {
      for (final size in const [Size(320, 568), Size(390, 844), Size(1024, 768), Size(1366, 1024)]) {
        final m = Metrics.from(size);
        expect(m.radius, 22 * m.scale);
        expect(m.innerRadius, 14 * m.scale);
        for (final r in [m.seatRadius, m.nextChipRadius, m.gaugePlateRadius, m.cabinRadius]) {
          expect(r, m.innerRadius, reason: '$size');
        }
      }
    });

    test('touch targets stay at 48 at every size', () {
      for (final size in const [Size(320, 568), Size(390, 844), Size(1366, 1024)]) {
        final m = Metrics.from(size);
        expect(m.seatHeight, greaterThanOrEqualTo(Metrics.minTouch));
        expect(m.dockButton, greaterThanOrEqualTo(Metrics.minTouch));
        expect(m.sendHeight, greaterThanOrEqualTo(Metrics.minTouch));
        expect(m.hudHeight, greaterThanOrEqualTo(Metrics.minTouch));
      }
    });
  });

  group('floors are told apart by colour and label, not by a shape', () {
    testWidgets('a floor tag is its label alone, and every tag is the same height', (tester) async {
      await _play(tester);
      final tags = find.byType(FloorTag);
      expect(tags, findsWidgets);
      final m = Metrics.from(const Size(390, 844));
      for (final e in tags.evaluate()) {
        final tag = find.byWidget(e.widget);
        expect(tester.getSize(tag).height, closeTo(Metrics.compactTagHeight * m.scale, 0.01));
        expect(find.descendant(of: tag, matching: find.byType(Text)), findsOneWidget);
        // No glyph beside it: the tag is the label plus its side padding.
        final label = tester.getSize(find.descendant(of: tag, matching: find.byType(Text))).width;
        expect(tester.getSize(tag).width, closeTo(label + 2 * 6 * m.scale, 0.5), reason: 'no glyph beside the label');
      }
    });

    test('every floor has its own colour and lit colour', () {
      final colours = {for (final f in Floor.values) FloorStyle.of(f).color};
      expect(colours, hasLength(Floor.values.length));
      for (final f in Floor.values) {
        expect(FloorStyle.of(f).light, isNot(FloorStyle.of(f).color));
      }
    });
  });

  group('the lift here shows its floors once', () {
    for (final kind in LiftKind.values) {
      testWidgets('a ${kind.name} lift: the display above the cabin, nothing inside it', (tester) async {
        _size(tester, const Size(390, 844));
        final c = controller(DebugAnalytics(), levelFor: (_) => variety(Venue.society, kind, null));
        c.startLevel();
        await tester.pumpWidget(app(PlayScreen(controller: c)));
        final cabin = _byType('_Cabin');
        expect(cabin, findsOneWidget);
        // No floor label and no floor pill in the cabin.
        expect(find.descendant(of: cabin, matching: find.textContaining(RegExp(r'\dF'))), findsNothing);
        expect(find.descendant(of: cabin, matching: find.textContaining('Up to')), findsNothing);
        expect(
          find.descendant(
              of: cabin, matching: find.byWidgetPredicate((w) => w is Glossy && w.depth == SurfaceDepth.tag)),
          findsNothing,
        );
        // The display names every floor this lift serves, each lit in its floor's colour.
        final display = find.byKey(LiftShaft.floorDisplayKey);
        expect(display, findsOneWidget);
        final rich = tester.widget<RichText>(find.descendant(of: display, matching: find.byType(RichText)).first);
        final spans = <TextSpan>[];
        rich.text.visitChildren((s) {
          if (s is TextSpan) spans.add(s);
          return true;
        });
        expect(c.game.liftFloors, hasLength(kind == LiftKind.express ? 2 : 1));
        for (final f in c.game.liftFloors) {
          expect(rich.text.toPlainText(), contains(f.label), reason: kind.name);
          expect(spans.firstWhere((s) => s.text == f.label).style?.color, FloorStyle.of(f).light, reason: f.label);
        }
        // What carries a rule stays: the kind's sign on every lift but a normal one.
        final sign = find.descendant(of: cabin, matching: find.text(LiftKindStyle.of(kind).sign));
        expect(sign, kind == LiftKind.normal ? findsNothing : findsOneWidget, reason: kind.name);
      });
    }

    testWidgets('the painted cabin (sprite art off) shows no floors either, and keeps its sign', (tester) async {
      _size(tester, const Size(390, 844));
      final c = controller(DebugAnalytics(), levelFor: (_) => variety(Venue.society, LiftKind.old, null));
      c.startLevel();
      await tester.pumpWidget(app(SpriteArtScope(enabled: false, child: PlayScreen(controller: c))));
      final cabin = _byType('_Cabin');
      expect(find.descendant(of: cabin, matching: find.textContaining(RegExp(r'\dF'))), findsNothing);
      expect(find.descendant(of: cabin, matching: find.text(LiftKindStyle.of(LiftKind.old).sign)), findsOneWidget);
      expect(find.byKey(LiftShaft.floorDisplayKey), findsOneWidget);
    });

    testWidgets('the NEXT strip starts with the lift after this one', (tester) async {
      final c = await _play(tester);
      final here = c.game.liftFloors;
      final chips = tester.widgetList(_byType('_NextChip')).toList();
      expect(chips, isNotEmpty);
      // `stop` is the chip's one public field.
      final first = (chips.first as dynamic).stop as LiftStop;
      expect(first.floors, c.game.upcomingLifts(3).first.floors);
      expect(first.floors, isNot(here), reason: 'the first NEXT chip is not the lift that is here');
    });

    testWidgets('after a send, the lift that was first in NEXT is the one on the display', (tester) async {
      final c = await _play(tester);
      final next = c.game.upcomingLifts(3).first;
      c.tapQueue(0);
      c.tapLift();
      c.send();
      await tester.pump();
      c.finishSend();
      await tester.pump();
      expect(c.game.liftFloors, next.floors);
      final plain = _plain(tester, find.byKey(LiftShaft.floorDisplayKey));
      for (final f in next.floors) {
        expect(plain, contains(f.label));
      }
    });
  });

  group('rules in the source', () {
    test('the scroll area reads no weight, no hidden queue, and counts nobody', () {
      final src = File('lib/ui/widgets/lane_scroller.dart').readAsStringSync();
      for (final word in ['.kg', 'unknownIds', '.queues', 'engine.dart', 'LiftGame', 'waiting']) {
        expect(src.contains(word), isFalse, reason: 'lane_scroller.dart mentions $word');
      }
    });

    test('the floor shape painter, its enum and the cabin floor pill are gone', () {
      expect(File('lib/ui/painters/floor_shape_painter.dart').existsSync(), isFalse);
      final files =
          Directory('lib/ui').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
      for (final f in files) {
        final src = f.readAsStringSync();
        expect(src.contains('FloorShape'), isFalse, reason: '${f.path} still names FloorShape');
        expect(src.contains('_FloorPill'), isFalse, reason: '${f.path} still has the cabin floor pill');
      }
    });
  });
}

/// A context for [PlayScrollBehavior.getScrollPhysics], which reads nothing from it.
class _FakeContext extends Fake implements BuildContext {}
