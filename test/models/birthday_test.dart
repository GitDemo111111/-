import 'package:birthday_keeper/models/birthday.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validate', () {
    test('合法日期', () {
      expect(const Birthday(month: 5, day: 20).validate(), isNull);
      expect(const Birthday(month: 1, day: 31).validate(), isNull);
      expect(const Birthday(month: 2, day: 29, year: 2024).validate(), isNull);
      expect(const Birthday(month: 2, day: 29).validate(), isNull);
    });

    test('非法月份', () {
      expect(const Birthday(month: 0, day: 1).validate(), isNotNull);
      expect(const Birthday(month: 13, day: 1).validate(), isNotNull);
    });

    test('非法日', () {
      expect(const Birthday(month: 5, day: 0).validate(), isNotNull);
      expect(const Birthday(month: 4, day: 31).validate(), isNotNull);
      expect(const Birthday(month: 2, day: 30).validate(), isNotNull);
    });

    test('平年的 2 月 29 日非法，闰年合法', () {
      expect(
        const Birthday(month: 2, day: 29, year: 2023).validate(),
        isNotNull,
      );
      expect(const Birthday(month: 2, day: 29, year: 2024).validate(), isNull);
    });

    test('农历只看月日', () {
      expect(
        const Birthday(
          month: 12,
          day: 30,
          calendar: BirthdayCalendar.lunar,
        ).validate(),
        isNull,
      );
      expect(
        const Birthday(
          month: 12,
          day: 31,
          calendar: BirthdayCalendar.lunar,
        ).validate(),
        isNotNull,
      );
    });

    test('年份超出范围时报错', () {
      expect(
        const Birthday(month: 1, day: 1, year: 1800).validate(),
        isNotNull,
      );
      expect(
        const Birthday(month: 1, day: 1, year: 2200).validate(),
        isNotNull,
      );
    });

    test('isValid 与 validate 一致', () {
      expect(const Birthday(month: 5, day: 20).isValid, isTrue);
      expect(const Birthday(month: 5, day: 32).isValid, isFalse);
    });
  });

  group('展示文本', () {
    test('公历', () {
      expect(
        const Birthday(year: 1995, month: 5, day: 20).displayLabel,
        '1995年5月20日',
      );
      expect(const Birthday(month: 5, day: 20).shortLabel, '5月20日');
      expect(const Birthday(month: 5, day: 20).displayLabel, '5月20日');
    });

    test('农历', () {
      expect(
        const Birthday(
          year: 1995,
          month: 5,
          day: 20,
          calendar: BirthdayCalendar.lunar,
        ).displayLabel,
        '农历1995年5月20日',
      );
      expect(
        const Birthday(
          month: 5,
          day: 20,
          calendar: BirthdayCalendar.lunar,
        ).shortLabel,
        '农历5月20日',
      );
    });

    test('农历闰月', () {
      expect(
        const Birthday(
          month: 6,
          day: 1,
          calendar: BirthdayCalendar.lunar,
          isLeapMonth: true,
        ).displayLabel,
        '农历闰6月1日',
      );
    });
  });

  group('辅助判断', () {
    test('hasYear / isSolar / isLunar / isSolarLeapDay', () {
      const Birthday withYear = Birthday(year: 2000, month: 2, day: 29);
      expect(withYear.hasYear, isTrue);
      expect(withYear.isSolar, isTrue);
      expect(withYear.isLunar, isFalse);
      expect(withYear.isSolarLeapDay, isTrue);

      const Birthday lunar = Birthday(
        month: 2,
        day: 29,
        calendar: BirthdayCalendar.lunar,
      );
      expect(lunar.isSolarLeapDay, isFalse);
      expect(lunar.hasYear, isFalse);
    });

    test('withoutYear 只保留月日', () {
      final Birthday result = const Birthday(
        year: 1990,
        month: 5,
        day: 20,
        calendar: BirthdayCalendar.lunar,
        isLeapMonth: true,
      ).withoutYear();
      expect(result.year, isNull);
      expect(result.month, 5);
      expect(result.day, 20);
      expect(result.calendar, BirthdayCalendar.lunar);
      expect(result.isLeapMonth, isTrue);
    });

    test('asDateTime 只对带年份的公历生日有意义', () {
      expect(
        const Birthday(year: 1990, month: 5, day: 20).asDateTime,
        DateTime(1990, 5, 20),
      );
      expect(const Birthday(month: 5, day: 20).asDateTime, isNull);
      expect(
        const Birthday(
          year: 1990,
          month: 5,
          day: 20,
          calendar: BirthdayCalendar.lunar,
        ).asDateTime,
        isNull,
      );
    });
  });

  group('JSON', () {
    test('公历往返一致', () {
      const Birthday original = Birthday(year: 1990, month: 5, day: 20);
      expect(Birthday.fromJson(original.toJson()), original);
    });

    test('农历闰月往返一致', () {
      const Birthday original = Birthday(
        month: 6,
        day: 18,
        year: 1995,
        calendar: BirthdayCalendar.lunar,
        isLeapMonth: true,
      );
      final Birthday restored = Birthday.fromJson(original.toJson());
      expect(restored, original);
      expect(restored.isLeapMonth, isTrue);
      expect(restored.calendar, BirthdayCalendar.lunar);
    });

    test('年份未知时不写入 year 字段', () {
      expect(
        const Birthday(month: 5, day: 20).toJson().containsKey('year'),
        isFalse,
      );
    });

    test('缺少 month/day 时抛 FormatException', () {
      expect(
        () => Birthday.fromJson(<String, Object?>{'day': 1}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Birthday.fromJson(<String, Object?>{'month': '5', 'day': 1}),
        throwsA(isA<FormatException>()),
      );
    });

    test('字段类型不对时退化为安全默认值', () {
      final Birthday parsed = Birthday.fromJson(<String, Object?>{
        'month': 5,
        'day': 20,
        'year': '1990',
        'calendar': '不存在的历法',
      });
      expect(parsed.year, isNull);
      expect(parsed.calendar, BirthdayCalendar.solar);
    });
  });

  group('相等性', () {
    test('所有字段都参与比较', () {
      expect(
        const Birthday(month: 5, day: 20),
        const Birthday(month: 5, day: 20),
      );
      expect(
        const Birthday(month: 5, day: 20),
        isNot(const Birthday(month: 5, day: 21)),
      );
      expect(
        const Birthday(month: 5, day: 20),
        isNot(const Birthday(month: 5, day: 20, year: 1990)),
      );
    });

    test('hashCode 一致', () {
      expect(
        const Birthday(month: 5, day: 20).hashCode,
        const Birthday(month: 5, day: 20).hashCode,
      );
    });
  });

  test('copyWith', () {
    const Birthday original = Birthday(year: 1990, month: 5, day: 20);
    expect(original.copyWith(day: 21).day, 21);
    expect(original.copyWith(day: 21).year, 1990);
  });

  test('BirthdayCalendar.fromName', () {
    expect(BirthdayCalendar.fromName('lunar'), BirthdayCalendar.lunar);
    expect(BirthdayCalendar.fromName('solar'), BirthdayCalendar.solar);
    expect(BirthdayCalendar.fromName(null), BirthdayCalendar.solar);
    expect(BirthdayCalendar.fromName('乱写'), BirthdayCalendar.solar);
  });
}
