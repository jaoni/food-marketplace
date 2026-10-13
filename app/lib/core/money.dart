/// Money is an `int` number of cents everywhere in the app, exactly as the
/// backend sends it (1050 means 10.50). This is the only place it becomes
/// text. It uses integer math only, so there are no rounding errors.
const currencySymbol = r'$';

String formatCents(int cents) {
  final sign = cents < 0 ? '-' : '';
  final whole = (cents.abs() ~/ 100)
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ','); // 1234 -> 1,234
  final fraction = (cents.abs() % 100).toString().padLeft(2, '0');
  return '$sign$currencySymbol$whole.$fraction';
}
