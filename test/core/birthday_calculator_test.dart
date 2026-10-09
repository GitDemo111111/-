import 'package:birthday_keeper/core/birthday_calculator.dart';
import 'package:birthday_keeper/core/lunar_converter.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:flutter_test/flutter_test.dart';

/// 农历 2024 年正月初一（春节）。
final DateTime kSpringFestival2024 = DateTime(2024, 2, 10);

void main() {
  const BirthdayCalculator calculator = BirthdayCalculator();

  group('公历生日的下一次', () {
    const Birthday birthday = Birthday(month: 5, day: 20);

    test('生日还没到时算今年', () {
      final BirthdayOccurrence? occurrence = calculator.nextOccurrence(
        birthday,
        DateTime(2026, 5, 19),
      );
      expect(occurrence!.date, DateTime(2026, 5, 20));
      expect(calculator.daysUntil(birthday, DateTime(2026, 5, 19)), 1);
    });

    test('生日当天算今天，倒计时为 0', () {
      expect(
        calculator.nextOccurrence(birthday, DateTime(2026, 5, 20))!.date,
        DateTime(2026, 5, 20),
      );
      expect(calculator.daysUntil(birthday, DateTime(2026, 5, 20)), 0);
      expect(
        calculator.isBirthdayToday(birthday, DateTime(2026, 5, 20)),
        isTrue,
      );
    });

    test('生日过了就算明年', () {
      final DateTime from = DateTime(2026, 5, 21);
      expect(
        calculator.nextOccurrence(birthday, from)!.date,
        DateTime(2027, 5, 20),
      );
      expect(calculator.daysUntil(birthday, from), 364);
    });

    test('时间部分不影响结果', () {
      expect(calculator.daysUntil(birthday, DateTime(2026, 5, 20, 23, 59)), 0);
    });
  });

  group('2 月 29 日', () {
    const Birthday leapDay = Birthday(month: 2, day: 29, year: 2000);

    test('平年收缩到 2 月 28 日', () {
      final BirthdayOccurrence? occurrence = calculator.nextOccurrence(
        leapDay,
        DateTime(2026, 1, 1),
      );
      expect(occurrence!.date, DateTime(2026, 2, 28));
      expect(calculator.daysUntil(leapDay, DateTime(2026, 1, 1)), 58);
    });

    test('闰年仍然是 2 月 29 日', () {
      expect(
        calculator.nextOccurrence(leapDay, DateTime(2028, 1, 1))!.date,
        DateTime(2028, 2, 29),
      );
      expect(calculator.daysUntil(leapDay, DateTime(2028, 1, 1)), 59);
    });

    test('3 月 1 日之后算下一年', () {
      expect(
        calculator.nextOccurrence(leapDay, DateTime(2026, 3, 1))!.date,
        DateTime(2027, 2, 28),
      );
    });
  });

  group('跨年', () {
    const Birthday newYearEve = Birthday(month: 12, day: 31);

    test('12 月 31 日的生日', () {
      expect(calculator.daysUntil(newYearEve, DateTime(2026, 12, 30)), 1);
      expect(calculator.daysUntil(newYearEve, DateTime(2026, 12, 31)), 0);
      expect(
        calculator.nextOccurrence(newYearEve, DateTime(2027, 1, 1))!.date,
        DateTime(2027, 12, 31),
      );
    });

    test('1 月 1 日的生日', () {
      const Birthday newYear = Birthday(month: 1, day: 1);
      expect(calculator.daysUntil(newYear, DateTime(2026, 12, 31)), 1);
    });
  });

  group('年龄', () {
    const Birthday birthday = Birthday(year: 1990, month: 5, day: 20);

    test('还没过生日：今年满 N 岁，当前 N-1 岁', () {
      final DateTime from = DateTime(2026, 5, 19);
      expect(calculator.turningAge(birthday, from), 36);
      expect(calculator.currentAge(birthday, from), 35);
    });

    test('生日当天：当前年龄就是把满年龄', () {
      final DateTime from = DateTime(2026, 5, 20);
      expect(calculator.turningAge(birthday, from), 36);
      expect(calculator.currentAge(birthday, from), 36);
    });

    test('生日之后：下一轮满 37 岁', () {
      final DateTime from = DateTime(2026, 5, 21);
      expect(calculator.turningAge(birthday, from), 37);
      expect(calculator.currentAge(birthday, from), 36);
    });

    test('出生年份未知时不显示年龄', () {
      const Birthday unknown = Birthday(month: 5, day: 20);
      expect(calculator.turningAge(unknown, DateTime(2026, 5, 19)), isNull);
      expect(calculator.currentAge(unknown, DateTime(2026, 5, 19)), isNull);
    });
  });

  group('星座与生肖', () {
    test('星座取自下一个生日的公历日期', () {
      const Birthday birthday = Birthday(month: 5, day: 20);
      expect(calculator.constellation(birthday, DateTime(2026, 1, 1)), '金牛座');
    });

    test('生肖需要出生年份', () {
      expect(
        calculator.chineseZodiac(const Birthday(year: 1990, month: 1, day: 1)),
        '马',
      );
      expect(
        calculator.chineseZodiac(const Birthday(month: 1, day: 1)),
        isNull,
      );
    });
  });

  group('nextOccurrences', () {
    test('连续取两次生日', () {
      const Birthday birthday = Birthday(month: 5, day: 20);
      final List<BirthdayOccurrence> list = calculator.nextOccurrences(
        birthday,
        DateTime(2026, 5, 20),
        2,
      );
      expect(list, hasLength(2));
      expect(list[0].date, DateTime(2026, 5, 20));
      expect(list[1].date, DateTime(2027, 5, 20));
    });
  });

  group('农历生日', () {
    const BirthdayCalculator withLunar = BirthdayCalculator(
      lunarConverter: LunarPackageConverter(),
    );

    test('农历正月初一就是春节', () {
      const Birthday birthday = Birthday(
        month: 1,
        day: 1,
        calendar: BirthdayCalendar.lunar,
      );
      expect(
        withLunar.occurrenceInYear(birthday, 2024)!.date,
        kSpringFestival2024,
      );
    });

    test('春节总在 1 月 21 日到 2 月 21 日之间', () {
      const Birthday birthday = Birthday(
        month: 1,
        day: 1,
        calendar: BirthdayCalendar.lunar,
      );
      for (int year = 2020; year <= 2032; year++) {
        final DateTime date = withLunar.occurrenceInYear(birthday, year)!.date;
        expect(date.year, year);
        expect(
          date.month,
          inInclusiveRange(1, 2),
          reason: '$year 年的春节应该在 1~2 月',
        );
        if (date.month == 1) {
          expect(date.day, greaterThanOrEqualTo(21));
        } else {
          expect(date.day, lessThanOrEqualTo(21));
        }
      }
    });

    test('农历生日每年都能落到对应的公历年', () {
      const Birthday midAutumn = Birthday(
        month: 8,
        day: 15,
        calendar: BirthdayCalendar.lunar,
      );
      for (int year = 2024; year <= 2030; year++) {
        final BirthdayOccurrence? occurrence = withLunar.occurrenceInYear(
          midAutumn,
          year,
        );
        expect(occurrence, isNotNull, reason: '$year 年中秋');
        expect(occurrence!.date.year, year);
        // 中秋总在 9~10 月。
        expect(occurrence.date.month, inInclusiveRange(9, 10));
      }
    });

    test('农历生日也有倒计时和年龄', () {
      const Birthday birthday = Birthday(
        year: 1990,
        month: 5,
        day: 5,
        calendar: BirthdayCalendar.lunar,
      );
      final DateTime from = DateTime(2026, 1, 1);
      final int? days = withLunar.daysUntil(birthday, from);
      expect(days, isNotNull);
      expect(days, greaterThan(0));
      expect(withLunar.turningAge(birthday, from), isNotNull);
    });

    test('支持闰月', () {
      // 2020~2030 之间一定有闰月，找出一个能换算的年份来验证。
      bool found = false;
      for (int year = 2020; year <= 2030 && !found; year++) {
        for (int month = 1; month <= 12; month++) {
          final LunarResolution? resolution = const LunarPackageConverter()
              .resolve(
                month: month,
                day: 15,
                lunarYear: year,
                isLeapMonth: true,
              );
          if (resolution == null) continue;
          final LunarDate lunar = const LunarPackageConverter().toLunar(
            resolution.solarDate,
          )!;
          if (lunar.isLeapMonth) {
            expect(lunar.month, month);
            expect(lunar.day, 15);
            found = true;
            break;
          }
        }
      }
      expect(found, isTrue, reason: '应该能找到闰月');
    });

    test('农历年末的生日不会被跳过', () {
      // 回归测试：农历一年比公历一年短，「农历十一月廿八」在同一个公历年内
      // 会出现两次。如果只按公历年去找，就可能漏掉 12 月那一次。
      const Birthday endOfYear = Birthday(
        month: 11,
        day: 28,
        calendar: BirthdayCalendar.lunar,
      );
      final BirthdayOccurrence? occurrence = withLunar.nextOccurrence(
        endOfYear,
        DateTime(2021, 12, 30),
      );
      expect(occurrence, isNotNull);
      expect(occurrence!.date, DateTime(2021, 12, 31));
    });

    test('不支持农历的实现会优雅降级', () {
      const BirthdayCalculator noLunar = BirthdayCalculator(
        lunarConverter: NoLunarConverter(),
      );
      const Birthday birthday = Birthday(
        month: 1,
        day: 1,
        calendar: BirthdayCalendar.lunar,
      );
      expect(noLunar.occurrenceInYear(birthday, 2026), isNull);
      expect(noLunar.daysUntil(birthday, DateTime(2026, 1, 1)), isNull);
      expect(noLunar.supportsLunar, isFalse);
      expect(withLunar.supportsLunar, isTrue);
    });
  });
}
