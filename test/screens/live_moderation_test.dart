import 'package:flutter_test/flutter_test.dart';
import 'package:militant/screens/live_screen.dart';

void main() {
  test('la modération ne conserve que les signalements de directs actifs', () {
    final reports = activeLiveModerationReports([
      {'id': 1, 'live_id': 10, 'live_status': 'ended'},
      {'id': 2, 'live_id': 11, 'live_status': 'live'},
      {'id': 3, 'live_id': 12},
    ]);

    expect(reports, hasLength(1));
    expect((reports.single as Map)['live_id'], 11);
  });
}
