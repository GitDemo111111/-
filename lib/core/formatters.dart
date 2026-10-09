/// 与日期文本有关的小工具（不依赖 Flutter，方便单测）。
library;

import 'date_x.dart';

/// `5月20日`
String formatMonthDay(DateTime date) => '${date.month}月${date.day}日';

/// `2026年5月20日`
String formatFullDate(DateTime date) =>
    '${date.year}年${date.month}月${date.day}日';

/// `2026-05-20`
String formatIsoDate(DateTime date) =>
    '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';

/// `周一` … `周日`
String weekdayLabel(DateTime date) =>
    const <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'][date.weekday - 1];

/// `2026年5月20日 周三`
String formatFullDateWithWeekday(DateTime date) =>
    '${formatFullDate(date)} ${weekdayLabel(date)}';

/// 距离生日的天数的自然说法。
String relativeDayLabel(int days) {
  if (days < 0) return '已过去';
  switch (days) {
    case 0:
      return '今天';
    case 1:
      return '明天';
    case 2:
      return '后天';
    default:
      return '$days天后';
  }
}

/// 年龄的说法，例如 `满26岁`。
String ageLabel(int age) => '满$age岁';
