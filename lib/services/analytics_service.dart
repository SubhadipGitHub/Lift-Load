import 'package:flutter/foundation.dart';

/// Analytics boundary. Event names are the contract with the dashboards
/// that check the PRD's gates; change them only together with docs/analytics.md.
abstract interface class AnalyticsService {
  void log(String event, [Map<String, Object> params = const {}]);
}

/// Prints events in debug builds. M3 adds a firebase_analytics implementation.
class DebugAnalytics implements AnalyticsService {
  final List<(String, Map<String, Object>)> history = [];

  @override
  void log(String event, [Map<String, Object> params = const {}]) {
    history.add((event, params));
    if (kDebugMode) debugPrint('[analytics] $event $params');
  }
}

/// Sends every event to each sink, e.g. the debug console and the Gate A
/// tester log.
class FanOutAnalytics implements AnalyticsService {
  FanOutAnalytics(this.sinks);

  final List<AnalyticsService> sinks;

  @override
  void log(String event, [Map<String, Object> params = const {}]) {
    for (final s in sinks) {
      s.log(event, params);
    }
  }
}
