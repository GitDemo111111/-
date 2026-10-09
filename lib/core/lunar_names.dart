/// 农历月份 / 日期的中文名称（纯数据，方便单测）。
library;

/// 农历月份名（不含「闰」前缀）。
const List<String> kLunarMonthNames = <String>[
  '正月',
  '二月',
  '三月',
  '四月',
  '五月',
  '六月',
  '七月',
  '八月',
  '九月',
  '十月',
  '冬月',
  '腊月',
];

const List<String> _digits = <String>[
  '',
  '一',
  '二',
  '三',
  '四',
  '五',
  '六',
  '七',
  '八',
  '九',
];

/// 农历日期的中文名称，例如 1 -> 初一，21 -> 廿一。
String lunarDayName(int day) {
  if (day < 1 || day > 30) return '$day';
  if (day == 10) return '初十';
  if (day == 20) return '二十';
  if (day == 30) return '三十';
  const List<String> prefixes = <String>['初', '十', '廿', '三'];
  final String prefix = prefixes[(day / 10).floor()];
  return '$prefix${_digits[day % 10]}';
}

/// 完整的农历月名，带闰月前缀。
String lunarMonthName(int month, {bool isLeapMonth = false}) {
  if (month < 1 || month > 12) return '$month月';
  return '${isLeapMonth ? '闰' : ''}${kLunarMonthNames[month - 1]}';
}
