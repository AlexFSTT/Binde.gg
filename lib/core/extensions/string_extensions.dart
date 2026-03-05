extension StringExt on String {
  String get capitalize => isEmpty ? '' : '${this[0].toUpperCase()}${substring(1)}';
  String get initials => split(' ').where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase()).take(2).join();
}
