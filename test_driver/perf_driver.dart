// Pilote des mesures de performance (P0.7) :
//   flutter drive --profile -d emulator-5554 \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/performance_test.dart
// Écrit build/ui_transitions.timeline_summary.json.
import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final timeline = data?['ui_transitions'];
    if (timeline is Map<String, dynamic>) {
      final summary = driver.TimelineSummary.summarize(
        driver.Timeline.fromJson(timeline),
      );
      await summary.writeTimelineToFile(
        'ui_transitions',
        pretty: true,
        includeSummary: true,
      );
    }
  },
);
