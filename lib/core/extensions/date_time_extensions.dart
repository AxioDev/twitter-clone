import 'package:timeago/timeago.dart' as timeago;

extension DateTimeX on DateTime {
  String get timeAgo => timeago.format(this);
}
