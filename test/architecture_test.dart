import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the two rules in CLAUDE.md that a reviewer could miss.
void main() {
  List<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

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
}
