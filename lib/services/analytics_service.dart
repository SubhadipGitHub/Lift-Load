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
