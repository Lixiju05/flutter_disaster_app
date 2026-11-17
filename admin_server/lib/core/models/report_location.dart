/// Parsing shared by report ingestion and dashboard selection. No network calls.
class ReportLocation {
  static double? latitude(Object? value) => _coordinate(value, 90);
  static double? longitude(Object? value) => _coordinate(value, 180);

  static double? _coordinate(Object? value, double limit) {
    final number = value is num
        ? value.toDouble()
        : value is String
        ? double.tryParse(value)
        : null;
    return number != null && number.isFinite && number.abs() <= limit
        ? number
        : null;
  }

  /// Reject malformed dates, including dates DateTime.tryParse normalizes.
  /// Offset-less ISO timestamps retain the existing local-time interpretation.
  static DateTime? time(Object? value) {
    if (value is DateTime) return value;
    if (value is! String) return null;
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[Tt ](\d{2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?(?:[zZ]|[+-]\d{2}:?\d{2})?$',
    ).firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > DateTime.utc(year, month + 1, 0).day ||
        int.parse(match[4]!) > 23 ||
        int.parse(match[5]!) > 59 ||
        int.parse(match[6] ?? '0') > 59) {
      return null;
    }
    final offset = RegExp(r'[+-](\d{2}):?(\d{2})$').firstMatch(value);
    if (offset != null &&
        (int.parse(offset[1]!) > 23 || int.parse(offset[2]!) > 59)) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
