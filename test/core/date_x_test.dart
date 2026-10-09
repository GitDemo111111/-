import 'package:birthday_keeper/core/date_x.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isLeapYear', () {
    test('百年不闰、四百年再闰', () {
      expect(isLeapYear(2024), isTrue);
      expect(isLeapYear(2026), isFalse);
      expect(isLeapYear(2000), isTrue);
      expect(isLeapYear(1900), isFalse);
      expect(isLeapYear(2100), isFalse);
    });
  });

  group('daysInSolarMonth', () {
    test('普通月份的天数', () {
      expect(daysInSolarMonth(2026, 1), 31);
      expect(daysInSolarMonth(2026, 4), 30);
      expect(daysInSolarMonth(2026, 12), 31);
    });

    test('2 月区分闰年', () {
      expect(daysInSolarMonth(2026, 2), 28);
      expect(daysInSolarMonth(2024, 2), 29);
    });

    test('非法月份返回 0', () {
      expect(daysInSolarMonth(2026, 0), 0);
      expect(daysInSolarMonth(2026, 13), 0);
    });
  });

  group('daysBetween', () {
    test('同一天为 0', () {
      expect(daysBetween(DateTime(2026, 5, 20), DateTime(2026, 5, 20)), 0);
    });

    test('忽略时间部分', () {
      expect(
        daysBetween(DateTime(2026, 5, 20, 23, 59), DateTime(2026, 5, 21, 0, 1)),
        1,
      );
    });

    test('跨月跨年都正确', () {
      expect(daysBetween(DateTime(2026, 5, 20), DateTime(2026, 6, 20)), 31);
      expect(daysBetween(DateTime(2025, 12, 31), DateTime(2026, 1, 1)), 1);
      expect(daysBetween(DateTime(2026, 1, 1), DateTime(2025, 12, 31)), -1);
    });

    test('夏令时切换当天依然算 1 天（用 UTC 求差）', () {
      // 美国 2026 年的夏令时切换发生在 3 月 8 日。
      expect(daysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 8)), 1);
      expect(daysBetween(DateTime(2026, 3, 8), DateTime(2026, 3, 9)), 1);
      // 11 月 1 日回拨。
      expect(daysBetween(DateTime(2026, 10, 31), DateTime(2026, 11, 1)), 1);
      expect(daysBetween(DateTime(2026, 11, 1), DateTime(2026, 11, 2)), 1);
    });
  });

  group('safeDate', () {
    test('平年的 2 月 29 日收缩到 2 月 28 日', () {
      expect(safeDate(2026, 2, 29), DateTime(2026, 2, 28));
    });

    test('闰年的 2 月 29 日保持不变', () {
      expect(safeDate(2024, 2, 29), DateTime(2024, 2, 29));
    });

    test('4 月 31 日收缩到 4 月 30 日', () {
      expect(safeDate(2026, 4, 31), DateTime(2026, 4, 30));
    });
  });

  group('isValidSolarDate', () {
    test('识别非法日期', () {
      expect(isValidSolarDate(2026, 2, 29), isFalse);
      expect(isValidSolarDate(2024, 2, 29), isTrue);
      expect(isValidSolarDate(2026, 4, 31), isFalse);
      expect(isValidSolarDate(2026, 0, 10), isFalse);
      expect(isValidSolarDate(2026, 5, 0), isFalse);
    });
  });

  test('twoDigits 补零', () {
    expect(twoDigits(9), '09');
    expect(twoDigits(10), '10');
    expect(twoDigits(0), '00');
  });

  test('dateOnly 去掉时间', () {
    expect(dateOnly(DateTime(2026, 5, 20, 13, 45, 30)), DateTime(2026, 5, 20));
  });
}
