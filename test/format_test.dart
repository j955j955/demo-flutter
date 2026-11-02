import 'package:demo_wallet/util/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money is formatted from integer cents', () {
    expect(formatCents(38999), r'$389.99');
    expect(formatCents(248130), r'$2,481.30');
    expect(formatCents(-640), r'-$6.40');
  });

  test('dates read like a banking app', () {
    final now = DateTime(2026, 11, 2, 11);
    expect(shortDate(DateTime(2026, 11, 2, 1, 14), now: now), 'Today, 1:14 AM');
    expect(shortDate(DateTime(2026, 11, 1, 20, 48), now: now), 'Yesterday, 8:48 PM');
    expect(shortDate(DateTime(2026, 10, 29, 20), now: now), 'Oct 29, 8:00 PM');
  });

  test('greeting follows the time of day', () {
    expect(greeting(DateTime(2026, 1, 1, 9)), 'Good morning');
    expect(greeting(DateTime(2026, 1, 1, 13)), 'Good afternoon');
    expect(greeting(DateTime(2026, 1, 1, 20)), 'Good evening');
  });

  test('IDs are masked for diagnostics', () {
    expect(maskId(''), '(not set)');
    expect(maskId('short'), '••••');
    expect(maskId('agent_0000example0000wxyz'), 'agent_…wxyz');
  });
}
