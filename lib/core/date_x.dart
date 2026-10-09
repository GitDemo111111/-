/// 纯 Dart 的日期工具。
///
/// 生日只关心「哪一天」，所以这里所有的计算都刻意丢掉时间部分，
/// 并且用 UTC 来求天数差，避免夏令时（DST）导致的 23/25 小时误差。
library;

/// 是否为闰年。
bool isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

const List<int> _daysInSolarMonth = <int>[
  31,
  28,
  31,
  30,
  31,
  30,
  31,
  31,
  30,
  31,
  30,
  31,
];

/// 公历某年某月有多少天。
int daysInSolarMonth(int year, int month) {
  if (month < 1 || month > 12) return 0;
  if (month == 2 && isLeapYear(year)) return 29;
  return _daysInSolarMonth[month - 1];
}

/// 校验月/日是否是一个合法的公历日期。
bool isValidSolarDate(int year, int month, int day) {
  if (month < 1 || month > 12) return false;
  if (day < 1) return false;
  return day <= daysInSolarMonth(year, month);
}

/// 去掉时间部分，只留下年月日。
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// 从 `from` 到 `to` 相差的天数（`to` 在 `from` 之后为正数）。
int daysBetween(DateTime from, DateTime to) {
  final DateTime a = DateTime.utc(from.year, from.month, from.day);
  final DateTime b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// 构造一个本地日期；若日超出了该月的天数，则收缩到当月最后一天。
///
/// 这样 2 月 29 日在平年会落到 2 月 28 日，而不是溢出到 3 月 1 日。
DateTime safeDate(int year, int month, int day) {
  final int maxDay = daysInSolarMonth(year, month);
  final int safeDay = day > maxDay ? maxDay : (day < 1 ? 1 : day);
  return DateTime(year, month, safeDay);
}

/// 两位数字，例如 `9` -> `09`。
String twoDigits(int value) => value < 10 ? '0$value' : '$value';
