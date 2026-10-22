import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the two rules in CLAUDE.md that a reviewer could miss.
void main() {
  List<File> dartFiles(String dir) =>
      Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  test('lib/game is pure Dart: no Flutter imports', () {
    for (final f in dartFiles('lib/game')) {
      final src = f.readAsStringSync();
      expect(src.contains('package:flutter'), isFalse, reason: '${f.path} imports Flutter');
      expect(src.contains('dart:ui'), isFalse, reason: '${f.path} imports dart:ui');
    }
  });

  test('UI never reads hidden weights', () {
    final kgRead = RegExp(r'\.kg\b');
    for (final f in [...dartFiles('lib/ui'), ...dartFiles('lib/services')]) {
      final src = f.readAsStringSync();
      expect(kgRead.hasMatch(src), isFalse, reason: '${f.path} reads .kg: weights must stay hidden');
      expect(src.contains("'kg'") || src.contains(' kg'), isFalse, reason: '${f.path} mentions kg');
    }
  });

  test('UI never reads the true lanes: unknown people must stay masked', () {
    // `queues` holds everyone with their real type. The UI goes through
    // visibleLanes / frontOf, which return null for an unknown person.
    final trueLanes = RegExp(r'\.queues\b');
    for (final f in [...dartFiles('lib/ui'), ...dartFiles('lib/services')]) {
      final src = f.readAsStringSync();
      expect(trueLanes.hasMatch(src), isFalse, reason: '${f.path} reads .queues: use visibleLanes or frontOf');
    }
  });

  test('widgets never read which people are unknown, only that a slot is', () {
    // GameController may count them for analytics; nothing it hands to a widget names one.
    for (final f in dartFiles('lib/ui').where((f) => !f.path.endsWith('game_controller.dart'))) {
      final src = f.readAsStringSync();
      expect(src.contains('unknownIds'), isFalse, reason: '${f.path} reads unknownIds');
    }
  });

  test('the punch on Send knows only the trip rating and its coins, never the load', () {
    // The score slam, coin fly, bump, hop and breathe must look the same
    // whoever rides: nothing in them may read the load, the capacity or the
    // Scale's preview.
    final src = File('lib/ui/widgets/punch.dart').readAsStringSync();
    for (final word in ['loadFraction', '.load', 'capacity', 'ghostLoad', 'zone', 'riders']) {
      expect(src.contains(word), isFalse, reason: 'punch.dart mentions $word');
    }
  });

  test('UI never shows how many people are waiting', () {
    final count = RegExp(
      r'(\$\{?[\w.]+\}?|\d+)\s+(more\s+)?waiting|\+\$\{?[\w.]+\}?\s+more',
      caseSensitive: false,
    );
    for (final f in dartFiles('lib/ui')) {
      for (final (i, line) in f.readAsLinesSync().indexed) {
        if (line.trimLeft().startsWith('//') || line.trimLeft().startsWith('///')) continue;
        expect(count.hasMatch(line), isFalse, reason: '${f.path}:${i + 1} may show a waiting count: $line');
      }
    }
  });
}
