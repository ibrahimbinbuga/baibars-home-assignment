import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/realtime/ticker.dart';
import '../../core/time_format.dart';

/// "4s ago" (with an optional prefix like "updated "), re-rendered every second by the ticker.
/// Only this small widget rebuilds each second, not the screen around it.
class TimeAgoText extends ConsumerWidget {
  const TimeAgoText(this.time, {super.key, this.prefix = '', this.style});

  final DateTime time;
  final String prefix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text('$prefix${timeAgo(time, ref.watch(tickerProvider))}', style: style);
}
