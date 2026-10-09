import 'package:birthday_keeper/core/lunar_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const LunarPackageConverter converter = LunarPackageConverter();

  group('toLunar', () {
    test('春节是农历正月初一', () {
      final LunarDate? lunar = converter.toLunar(DateTime(2024, 2, 10));
      expect(lunar, isNotNull);
      expect(lunar!.year, 2024);
      expect(lunar.month, 1);
      expect(lunar.day, 1);
      expect(lunar.isLeapMonth, isFalse);
      expect(lunar.label, '农历正月初一');
    });

    test('除夕是腊月', () {
      final LunarDate? lunar = converter.toLunar(DateTime(2024, 2, 9));
      expect(lunar, isNotNull);
      expect(lunar!.month, 12);
    });

    test('中文标签可读', () {
      final LunarDate lunar = converter.toLunar(DateTime(2026, 1, 1))!;
      expect(lunar.label, startsWith('农历'));
      expect(lunar.label, contains('月'));
    });
  });

  group('resolve', () {
    test('农历正月初一就是春节', () {
      final LunarResolution? resolution = converter.resolve(
        month: 1,
        day: 1,
        lunarYear: 2024,
      );
      expect(resolution, isNotNull);
      expect(resolution!.solarDate, DateTime(2024, 2, 10));
      expect(resolution.lunarYear, 2024);
    });

    test('每个农历月日都能换算成唯一一个公历日期', () {
      for (int lunarYear = 2022; lunarYear <= 2030; lunarYear++) {
        for (int month = 1; month <= 12; month++) {
          final LunarResolution? resolution = converter.resolve(
            month: month,
            day: 15,
            lunarYear: lunarYear,
          );
          expect(resolution, isNotNull, reason: '农历 $lunarYear-$month-15');
          final LunarDate back = converter.toLunar(resolution!.solarDate)!;
          expect(back.year, lunarYear);
          expect(back.month, month);
          expect(back.day, 15);
          expect(back.isLeapMonth, isFalse);
        }
      }
    });

    test('公历 -> 农历 -> 公历 往返一致', () {
      for (int year = 2021; year <= 2030; year++) {
        for (final (int month, int day) in <(int, int)>[
          (1, 1),
          (1, 20),
          (3, 15),
          (6, 20),
          (9, 9),
          (12, 31),
        ]) {
          final DateTime solar = DateTime(year, month, day);
          final LunarDate lunar = converter.toLunar(solar)!;
          final LunarResolution? back = converter.resolve(
            month: lunar.month,
            day: lunar.day,
            lunarYear: lunar.year,
            isLeapMonth: lunar.isLeapMonth,
          );
          expect(
            back?.solarDate,
            solar,
            reason: '$solar -> $lunar -> ${back?.solarDate}',
          );
        }
      }
    });

    test('同一个农历月日在一个公历年内可能出现两次，但农历年不同', () {
      // 农历一年比公历一年短，所以「十一月廿八」这种年末的日期，
      // 在同一个公历年内会出现两次（分别属于相邻的两个农历年）。
      // 这正是 resolve 必须以农历年（而不是公历年）为基准的原因。
      final LunarResolution? previous = converter.resolve(
        month: 11,
        day: 28,
        lunarYear: 2020,
      );
      final LunarResolution? current = converter.resolve(
        month: 11,
        day: 28,
        lunarYear: 2021,
      );
      expect(previous, isNotNull);
      expect(current, isNotNull);
      expect(previous!.solarDate.year, 2021);
      expect(current!.solarDate.year, 2021);
      expect(previous.solarDate.isBefore(current.solarDate), isTrue);
      expect(previous.solarDate, DateTime(2021, 1, 11));
      expect(current.solarDate, DateTime(2021, 12, 31));
    });

    test('支持闰月', () {
      // 2020~2030 之间一定存在闰月，找出一个并验证换算。
      LunarResolution? leapResolution;
      for (
        int lunarYear = 2020;
        lunarYear <= 2030 && leapResolution == null;
        lunarYear++
      ) {
        for (int month = 1; month <= 12; month++) {
          final LunarResolution? candidate = converter.resolve(
            month: month,
            day: 10,
            lunarYear: lunarYear,
            isLeapMonth: true,
          );
          if (candidate == null) continue;
          final LunarDate back = converter.toLunar(candidate.solarDate)!;
          if (back.isLeapMonth) {
            leapResolution = candidate;
            expect(back.month, month);
            expect(back.day, 10);
            break;
          }
        }
      }
      expect(leapResolution, isNotNull, reason: '2020~2030 之间应该存在至少一个有闰月的年份');
    });

    test('闰月不存在时退回普通月份，不会丢失生日', () {
      // 找一个「没有闰 X 月」的组合，确认它退化成普通的 X 月。
      final LunarResolution? resolution = converter.resolve(
        month: 3,
        day: 10,
        lunarYear: 2023,
        isLeapMonth: true,
      );
      expect(resolution, isNotNull);
      final LunarDate back = converter.toLunar(resolution!.solarDate)!;
      expect(back.month, 3);
      expect(back.day, 10);
    });

    test('非法输入返回 null 而不是抛异常', () {
      expect(converter.resolve(month: 0, day: 1, lunarYear: 2026), isNull);
      expect(converter.resolve(month: 13, day: 1, lunarYear: 2026), isNull);
      expect(converter.resolve(month: 1, day: 0, lunarYear: 2026), isNull);
      expect(converter.resolve(month: 1, day: 31, lunarYear: 2026), isNull);
    });

    test('任意组合都不抛异常，且结果能回读一致', () {
      for (int lunarYear = 2024; lunarYear <= 2027; lunarYear++) {
        for (int month = 1; month <= 12; month++) {
          for (int day = 1; day <= 30; day++) {
            for (final bool leap in <bool>[false, true]) {
              final LunarResolution? resolution = converter.resolve(
                month: month,
                day: day,
                lunarYear: lunarYear,
                isLeapMonth: leap,
              );
              if (resolution == null) continue;
              final LunarDate back = converter.toLunar(resolution.solarDate)!;
              expect(back.month, month);
              expect(back.day, day);
            }
          }
        }
      }
    });
  });

  test('NoLunarConverter 始终不可用', () {
    const NoLunarConverter none = NoLunarConverter();
    expect(none.isAvailable, isFalse);
    expect(none.resolve(month: 1, day: 1, lunarYear: 2026), isNull);
    expect(none.toLunar(DateTime(2026, 1, 1)), isNull);
    expect(converter.isAvailable, isTrue);
  });
}
