import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'tester_config.dart';

export 'tester_config.dart';

/// Keeps the events Gate A needs on the device, so a tester can send them
/// back as one file or pasted code. No backend, no account, no personal
/// data: the tester is a random three-word code. Like every analytics sink
/// it only sees event names and their params, never a weight.
class TesterLog implements AnalyticsService {
  TesterLog({required this.code, List<Map<String, Object?>>? events, this.persist, DateTime Function()? clock})
      : events = events ?? [],
        _clock = clock ?? DateTime.now;

  static const String _key = 'lift_load.tester_log.v1';

  /// Far above a full 60-level run (about a thousand events); past it new
  /// events are counted in [dropped] instead of growing the save.
  static const int maxEvents = 5000;

  /// What the Gate A report reads (trip_sent for the fill check on the
  /// puffer-jacket teen, docs/analytics.md). Taps, ads and settings stay out
  /// to keep the returned file small.
  static const Set<String> kept = {
    'level_start',
    'trip_sent',
    'level_win',
    'level_fail',
    'level_abandon',
    'overload',
    'crash_fairness',
    'exit_heavy_types',
    'exit_unknown_fair',
    // Powers (PRD v1.6, "Gate A"): what was used, bought, refilled by the stub ad, and wanted while empty.
    'power_used',
    'power_bought',
    'power_refill_ad',
    'power_empty_tapped',
    'test_complete',
  };

  final String code;
  final List<Map<String, Object?>> events;
  final void Function(String json)? persist;
  final DateTime Function() _clock;
  int dropped = 0;

  static Future<TesterLog> open(SharedPreferences prefs, {Random? random}) async {
    final raw = prefs.getString(_key);
    final saved = raw == null ? null : _tryDecode(raw);
    void persist(String json) => prefs.setString(_key, json);
    if (saved == null) {
      final log = TesterLog(code: newCode(random ?? Random()), persist: persist);
      log._save();
      return log;
    }
    return TesterLog(
      code: saved['tester'] as String,
      events: [for (final e in saved['events'] as List) Map<String, Object?>.from(e as Map)],
      persist: persist,
    )..dropped = (saved['dropped'] as num?)?.toInt() ?? 0;
  }

  static Map<String, dynamic>? _tryDecode(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return j['tester'] is String && j['events'] is List ? j : null;
    } on Object {
      return null;
    }
  }

  static const List<String> _words = [
    'amber', 'brass', 'cable', 'cedar', 'cobalt', 'coral', 'delta', 'ember', 'fern', 'glow', 'harbor', 'indigo', //
    'jade', 'kite', 'lemon', 'maple', 'mint', 'nova', 'olive', 'pebble', 'quartz', 'river', 'saffron', 'teal', //
    'tulip', 'umber', 'velvet', 'willow', 'zinc', 'lotus', 'marble', 'orbit',
  ];

  static String newCode(Random random) => List.generate(3, (_) => _words[random.nextInt(_words.length)]).join('-');

  /// True once the heavy-types question was answered or skipped.
  bool get heavyTypesAsked => events.any((e) => e['e'] == 'exit_heavy_types');

  /// True once the unknown-people question was answered or skipped.
  bool get unknownFairAsked => events.any((e) => e['e'] == 'exit_unknown_fair');

  /// The level the heavy-types question was answered on, or null.
  int? get heavyTypesLevel =>
      events.where((e) => e['e'] == 'exit_heavy_types').map((e) => (e['level'] as num).toInt()).firstOrNull;

  @override
  void log(String event, [Map<String, Object> params = const {}]) {
    if (!kept.contains(event)) return;
    if (events.length >= maxEvents) {
      dropped++;
    } else {
      events.add({'t': _clock().millisecondsSinceEpoch ~/ 1000, 'e': event, ...params});
    }
    _save();
  }

  void _save() => persist?.call(jsonEncode(_body()));

  Map<String, Object?> _body() => {'format': GateAFormat.format, 'tester': code, 'dropped': dropped, 'events': events};

  /// The file a tester sends back.
  Map<String, Object?> export() => {..._body(), 'exported': _clock().toUtc().toIso8601String()};

  String exportJson() => const JsonEncoder.withIndent(' ').convert(export());

  /// The same content as one pasteable line.
  String exportCode() => GateAFormat.toCode(jsonEncode(export()));
}
