import 'dart:async';

import 'package:flutter/material.dart';

import '../util/format.dart';

/// "01:37" since [since], ticking by itself so only this text rebuilds every
/// second, not the screen around it.
class ElapsedText extends StatefulWidget {
  const ElapsedText({super.key, required this.since, this.prefix = '', this.style});

  final DateTime since;
  final String prefix;
  final TextStyle? style;

  @override
  State<ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<ElapsedText> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    '${widget.prefix}${formatDuration(DateTime.now().difference(widget.since))}',
    style: widget.style,
  );
}
