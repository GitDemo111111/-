import 'package:birthday_keeper/core/formatters.dart';
import 'package:birthday_keeper/core/lunar_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lunarDayName', () {
    test('常见的农历日期写法', () {
      expect(lunarDayName(1), '初一');
      expect(lunarDayName(9), '初九');
      expect(lunarDayName(10), '初十');
      expect(lunarDayName(11), '十一');
      expect(lunarDayName(19), '十九');
      expect(lunarDayName(20), '二十');
      expect(lunarDayName(21), '廿一');
      expect(lunarDayName(29), '廿九');
      expect(lunarDayName(30), '三十');
    });

    test('越界时退化成数字', () {
      expect(lunarDayName(0), '0');
      expect(lunarDayName(31), '31');
    });
  });

  group('lunarMonthName', () {
    test('月份名称', () {
      expect(lunarMonthName(1), '正月');
      expect(lunarMonthName(5), '五月');
      expect(lunarMonthName(11), '冬月');
      expect(lunarMonthName(12), '腊月');
    });

    test('闰月带前缀', () {
      expect(lunarMonthName(5, isLeapMonth: true), '闰五月');
    });
  });

  group('日期格式化', () {
    test('月日 / 完整日期 / ISO', () {
      final DateTime date = DateTime(2026, 5, 20);
      expect(formatMonthDay(date), '5月20日');
      expect(formatFullDate(date), '2026年5月20日');
      expect(formatIsoDate(date), '2026-05-20');
      expect(formatIsoDate(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('星期', () {
      expect(weekdayLabel(DateTime(2026, 5, 20)), '周三');
      expect(weekdayLabel(DateTime(2026, 5, 18)), '周一');
      expect(weekdayLabel(DateTime(2026, 5, 24)), '周日');
      expect(formatFullDateWithWeekday(DateTime(2026, 5, 20)), '2026年5月20日 周三');
    });
  });

  group('relativeDayLabel', () {
    test('临近的说法', () {
      expect(relativeDayLabel(0), '今天');
      expect(relativeDayLabel(1), '明天');
      expect(relativeDayLabel(2), '后天');
      expect(relativeDayLabel(3), '3天后');
      expect(relativeDayLabel(30), '30天后');
      expect(relativeDayLabel(-1), '已过去');
    });
  });

  test('ageLabel', () {
    expect(ageLabel(26), '满26岁');
  });
}
