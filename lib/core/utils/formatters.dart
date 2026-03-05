import 'package:intl/intl.dart';

/// Display formatting helpers.
class Formatters {
  Formatters._();

  static final _currencyFormat = NumberFormat.currency(symbol: '€', decimalDigits: 2);
  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _timeFormat = DateFormat('HH:mm');
  static final _dateTimeFormat = DateFormat('dd MMM yyyy, HH:mm');

  static String currency(double amount) => _currencyFormat.format(amount);
  static String date(DateTime dt) => _dateFormat.format(dt);
  static String time(DateTime dt) => _timeFormat.format(dt);
  static String dateTime(DateTime dt) => _dateTimeFormat.format(dt);
  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(dt);
  }

  static String kda(int kills, int deaths, int assists) => '$kills/$deaths/$assists';
  static String winRate(int won, int played) =>
      played == 0 ? '0%' : '${(won / played * 100).toStringAsFixed(1)}%';
  static String elo(int rating) => rating.toString();
  static String eloChange(int change) => change >= 0 ? '+$change' : '$change';
}
