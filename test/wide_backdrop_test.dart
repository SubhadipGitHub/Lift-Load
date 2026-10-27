import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lift_load/ui/art_assets.dart';
import 'package:lift_load/ui/widgets/resident_figure.dart';
import 'package:lift_load/ui/widgets/wide_backdrop.dart';

void main() {
  const content = SizedBox.expand(key: Key('content'));

  Widget at(Size size, {bool sprites = true}) => MediaQuery(
        data: MediaQueryData(size: size),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SpriteArtScope(enabled: sprites, child: const WideBackdrop(child: content)),
        ),
      );

  Finder landscape() => find.byKey(const Key('wideBackdropLandscape'));
  Finder portrait() => find.byKey(const Key('wideBackdropPortrait'));

  group('WideBackdrop', () {
    testWidgets('a landscape window, tablet or phone on its side shows the landscape cover behind the content',
        (tester) async {
      for (final size in const [Size(1280, 720), Size(1024, 768), Size(1920, 1080), Size(844, 390)]) {
        await tester.pumpWidget(at(size));
        expect(find.byKey(const Key('content')), findsOneWidget, reason: '$size');
        expect(landscape(), findsOneWidget, reason: '$size');
        expect(portrait(), findsNothing, reason: '$size');
      }
    });

    testWidgets('a tablet standing up shows the portrait cover', (tester) async {
      for (final size in const [Size(820, 1180), Size(768, 1024), Size(600, 960)]) {
        await tester.pumpWidget(at(size));
        expect(portrait(), findsOneWidget, reason: '$size');
        expect(landscape(), findsNothing, reason: '$size');
      }
    });

    testWidgets('a phone gets the content alone, and the image is never asked for', (tester) async {
      for (final size in const [Size(320, 568), Size(360, 640), Size(390, 844), Size(430, 932)]) {
        await tester.pumpWidget(at(size));
        expect(find.byType(Image), findsNothing, reason: '$size');
        expect(find.byKey(const Key('content')), findsOneWidget, reason: '$size');
      }
    });

    testWidgets('sprite art off keeps the flat page on a wide screen', (tester) async {
      await tester.pumpWidget(at(const Size(1280, 720), sprites: false));
      expect(find.byType(Image), findsNothing);
      expect(find.byKey(const Key('content')), findsOneWidget);
    });

    testWidgets('the scrim is navy and the art is hidden from semantics and touches', (tester) async {
      await tester.pumpWidget(at(const Size(1280, 720)));
      expect(find.ancestor(of: landscape(), matching: find.byType(ExcludeSemantics)), findsOneWidget);
      expect(find.byType(IgnorePointer), findsWidgets);
      expect(WideBackdropStyle.scrim.a, greaterThanOrEqualTo(0.35));
    });

    testWidgets('a missing image leaves the content on the flat page, no error', (tester) async {
      await tester.pumpWidget(
        DefaultAssetBundle(bundle: _EmptyBundle(), child: at(const Size(1280, 720))),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('content')), findsOneWidget);
    });
  });

  group('the cover art files', () {
    test('both ship, outside the sprite table', () {
      for (final l in [true, false]) {
        final path = ArtAssets.coverArt(landscape: l);
        expect(File(path).existsSync(), isTrue, reason: path);
        expect(ArtAssets.all, isNot(contains(path)), reason: 'never preloaded');
      }
      expect(Directory('assets/cover').listSync().length, 2);
    });

    test('the shipped copies are the approved cover art', () {
      for (final (shipped, approved) in [
        ('assets/cover/cover_landscape.webp', 'docs/art/approved/home_skyline_landscape.webp'),
        ('assets/cover/cover_portrait.webp', 'docs/art/approved/home_skyline_portrait.webp'),
      ]) {
        expect(File(shipped).readAsBytesSync(), File(approved).readAsBytesSync(), reason: shipped);
      }
    });

    test('the play screen draws on the backdrop, and the backdrop reads nothing of the game', () {
      expect(File('lib/ui/screens/play_screen.dart').readAsStringSync(), contains('WideBackdrop('));
      final src = File('lib/ui/widgets/wide_backdrop.dart').readAsStringSync();
      for (final word in ['.kg', 'unknownIds', '.queues', 'engine.dart', 'LiftGame', 'GameController']) {
        expect(src.contains(word), isFalse, reason: 'wide_backdrop.dart mentions $word');
      }
    });
  });
}

/// The real bundle, except the cover art is gone.
class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      key.startsWith('assets/cover/') ? Future.error(FlutterError('no asset $key')) : rootBundle.load(key);
}
