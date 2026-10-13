import 'package:flutter/material.dart';

/// "Oct 12, 7:35 AM" in the user's locale and time zone. The backend sends
/// UTC times; toLocal() converts them.
String formatDateTime(BuildContext context, DateTime utc) {
  final local = utc.toLocal();
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatShortMonthDay(local)}, '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
