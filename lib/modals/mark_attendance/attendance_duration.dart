
class AttendanceDuration {
  AttendanceDuration._();

  static Duration? parse(dynamic value) {
    if (value == null) return null;
    if (value is Duration) return value;
    if (value is num) {
      return Duration(milliseconds: value.toInt());
    }

    final input = value.toString().trim();
    if (input.isEmpty) return null;

    // ISO-8601 duration: P[nD]T[nH][nM][nS]
    final regex = RegExp(
      r'^(-)?P(?:(\d+(?:[.,]\d+)?)D)?'
      r'(?:T(?:(\d+(?:[.,]\d+)?)H)?'
      r'(?:(\d+(?:[.,]\d+)?)M)?'
      r'(?:(\d+(?:[.,]\d+)?)S)?)?$',
      caseSensitive: false,
    );

    final match = regex.firstMatch(input);
    if (match == null) return null;

    double number(int index) {
      return double.tryParse(
            (match.group(index) ?? '0').replaceAll(',', '.'),
          ) ??
          0;
    }

    final totalSeconds = number(2) * 86400 +
        number(3) * 3600 +
        number(4) * 60 +
        number(5);

    final micros = (totalSeconds * 1000000).round();
    return Duration(
      microseconds: match.group(1) == '-' ? -micros : micros,
    );
  }

  static String? toIso(Duration? duration) {
    if (duration == null) return null;

    final negative = duration.isNegative;
    final value = duration.abs();

    final days = value.inDays;
    final hours = value.inHours % 24;
    final minutes = value.inMinutes % 60;
    final seconds = value.inSeconds % 60;
    final micros = value.inMicroseconds % 1000000;

    final result = StringBuffer(negative ? '-P' : 'P');

    if (days > 0) result.write('${days}D');

    if (hours > 0 || minutes > 0 || seconds > 0 || micros > 0 || days == 0) {
      result.write('T');

      if (hours > 0) result.write('${hours}H');
      if (minutes > 0) result.write('${minutes}M');

      if (seconds > 0 || micros > 0 || (hours == 0 && minutes == 0)) {
        final secondsText = micros == 0
            ? '$seconds'
            : '$seconds.${micros.toString().padLeft(6, '0').replaceFirst(RegExp(r'0+$'), '')}';
        result.write('${secondsText}S');
      }
    }

    return result.toString();
  }

  static String format(Duration? duration) {
    if (duration == null) return '--';

    final value = duration.abs();
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    final seconds = value.inSeconds.remainder(60);

    final text = hours > 0
        ? '${hours}h ${minutes}m'
        : minutes > 0
            ? '${minutes}m ${seconds}s'
            : '${seconds}s';

    return duration.isNegative ? '-$text' : text;
  }
}