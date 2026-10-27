import 'dart:convert';

// Plain Dart (no Flutter), so tool/gate_a_report.dart can use it with
// `dart run`.

/// The Gate A tester build (PRD v1.4). On only when built with
/// `--dart-define=TESTER=true`, which the Pages tester build does; the
/// Android build never sets it.
class TesterConfig {
  const TesterConfig({this.enabled = false});

  static const TesterConfig fromEnvironment = TesterConfig(enabled: bool.fromEnvironment('TESTER'));

  /// Gate A measures levels 1–60 only; World 2 starts at 61.
  static const int lastLevel = 60;

  /// Once-only free-text question after this level's win.
  static const int heavyTypesAfterLevel = 15;

  /// Once-only question after a win on a level with unknown people, from this level on (they debut at 11, so the
  /// tester has met a few by now). Never on the same win as the heavy-types question.
  static const int unknownFairAfterLevel = 13;

  final bool enabled;
}

/// The results file testers send back: JSON, or the same JSON as one
/// pasteable line.
abstract final class GateAFormat {
  static const String format = 'lift-load-gate-a/1';
  static const String codePrefix = 'LLGA1.';

  static String toCode(String json) => codePrefix + base64Url.encode(utf8.encode(json));

  /// Reads either form back (a .json file or a pasted code).
  static Map<String, dynamic> decode(String text) {
    final t = text.trim();
    final json = t.startsWith(codePrefix) ? utf8.decode(base64Url.decode(t.substring(codePrefix.length))) : t;
    final j = jsonDecode(json) as Map<String, dynamic>;
    if (j['format'] != format) throw FormatException('Not a Lift Load Gate A result (format ${j['format']})');
    return j;
  }
}
