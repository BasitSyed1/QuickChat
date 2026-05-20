import 'package:intl/intl.dart';

class TimeFormat {
  static String chatListTime(DateTime time) {
    final now = DateTime.now();
    final local = time.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final daysAgo = today.difference(that).inDays;

    if (daysAgo == 0) return DateFormat.jm().format(local);
    if (daysAgo == 1) return 'Yesterday';
    if (daysAgo < 7) return DateFormat.E().format(local);
    return DateFormat.yMd().format(local);
  }

  static String bubbleTime(DateTime time) {
    return DateFormat.jm().format(time.toLocal());
  }

  /// "Online", "Last seen just now", "Last seen 5 min ago",
  /// "Last seen today at 4:30 PM", "Last seen yesterday at 9:12 PM",
  /// "Last seen Mar 5 at 2:14 PM".
  static String lastSeen(DateTime? time, {bool isOnline = false}) {
    if (isOnline) return 'Online';
    if (time == null) return 'Offline';
    final now = DateTime.now();
    final local = time.toLocal();
    final diff = now.difference(local);

    if (diff.inSeconds < 60) return 'Last seen just now';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes} min ago';
    if (diff.inHours < 6) return 'Last seen ${diff.inHours} hr ago';

    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final daysAgo = today.difference(that).inDays;
    final t = DateFormat.jm().format(local);

    if (daysAgo == 0) return 'Last seen today at $t';
    if (daysAgo == 1) return 'Last seen yesterday at $t';
    if (daysAgo < 7) return 'Last seen ${DateFormat.EEEE().format(local)} at $t';
    return 'Last seen ${DateFormat.MMMd().format(local)} at $t';
  }
}
