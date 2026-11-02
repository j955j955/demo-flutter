import 'package:intl/intl.dart';

final _usd = NumberFormat.simpleCurrency(name: 'USD');

/// Money is stored as integer cents and only turned into text here.
String formatCents(int cents) => _usd.format(cents / 100);

/// "01:37".
String formatDuration(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:'
    '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// "Today, 1:14 AM", "Yesterday, 8:48 PM" or "Oct 29, 8:00 PM".
String shortDate(DateTime date, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final time = DateFormat('h:mm a').format(date);
  return switch (today.difference(day).inDays) {
    0 => 'Today, $time',
    1 => 'Yesterday, $time',
    _ => '${DateFormat('MMM d').format(date)}, $time',
  };
}

String greeting(DateTime now) => switch (now.hour) {
  < 12 => 'Good morning',
  < 18 => 'Good afternoon',
  _ => 'Good evening',
};

/// Hides the middle of an identifier so it can appear in diagnostics.
String maskId(String id) {
  if (id.isEmpty) return '(not set)';
  if (id.length <= 10) return '••••';
  return '${id.substring(0, 6)}…${id.substring(id.length - 4)}';
}
