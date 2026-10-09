import 'package:lunar/lunar.dart';
import 'package:meta/meta.dart';

/// 把一个农历月/日落到某个公历年份上的结果。
@immutable
class LunarResolution {
  const LunarResolution({required this.solarDate, required this.lunarYear});

  /// 换算出来的公历日期。
  final DateTime solarDate;

  /// 该公历日期所属的农历年份（用于计算年龄）。
  final int lunarYear;
}

/// 一个公历日期对应的农历日期。
@immutable
class LunarDate {
  const LunarDate({
    required this.year,
    required this.month,
    required this.day,
    required this.isLeapMonth,
    required this.monthName,
    required this.dayName,
  });

  final int year;
  final int month;
  final int day;
  final bool isLeapMonth;

  /// 中文月名，例如 `五`。
  final String monthName;

  /// 中文日名，例如 `初五`。
  final String dayName;

  /// 例如 `农历五月初五`。
  String get label => '农历${isLeapMonth ? '闰' : ''}$monthName月$dayName';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LunarDate &&
          other.year == year &&
          other.month == month &&
          other.day == day &&
          other.isLeapMonth == isLeapMonth;

  @override
  int get hashCode => Object.hash(year, month, day, isLeapMonth);

  @override
  String toString() => 'LunarDate($label)';
}

/// 农历换算能力的抽象。
///
/// 抽出接口是为了让核心逻辑可以在不依赖真实农历库的情况下被测试。
abstract class LunarConverter {
  /// 当前实现是否可用。
  bool get isAvailable;

  /// 把「农历 [lunarYear] 年 [month] 月 [day] 日」换算成公历日期。
  ///
  /// 这里刻意以**农历年**为基准，而不是公历年：农历一年只有约 354 天，
  /// 比公历年短，所以同一个「农历月日」在一个公历年内可能出现两次
  /// （例如农历十一月廿八既可能落在 1 月，也可能落在 12 月）。
  /// 以农历年为基准才能保证一次农历生日对应唯一一个公历日期。
  ///
  /// 无法换算（闰月不存在、当月没有这一天等）时返回 `null`。
  LunarResolution? resolve({
    required int month,
    required int day,
    required int lunarYear,
    bool isLeapMonth = false,
  });

  /// 公历日期对应的农历日期。
  LunarDate? toLunar(DateTime date);
}

/// 基于 `lunar` 包的实现。
class LunarPackageConverter implements LunarConverter {
  const LunarPackageConverter();

  @override
  bool get isAvailable => true;

  @override
  LunarResolution? resolve({
    required int month,
    required int day,
    required int lunarYear,
    bool isLeapMonth = false,
  }) {
    if (month < 1 || month > 12 || day < 1 || day > 30) return null;

    if (isLeapMonth) {
      final LunarResolution? leap = _tryResolve(
        lunarYear: lunarYear,
        signedMonth: -month,
        day: day,
      );
      // 该农历年没有这个闰月时，退回到普通月份，避免生日凭空消失。
      if (leap != null) return leap;
    }
    return _tryResolve(lunarYear: lunarYear, signedMonth: month, day: day);
  }

  LunarResolution? _tryResolve({
    required int lunarYear,
    required int signedMonth,
    required int day,
  }) {
    try {
      final Lunar lunar = Lunar.fromYmd(lunarYear, signedMonth, day);
      // 回读校验：闰月不存在或当月没有这一天时，库会「纠正」成别的日期，
      // 这种结果要丢弃而不是默默接受。
      if (lunar.getMonth() != signedMonth || lunar.getDay() != day) {
        return null;
      }
      final Solar solar = lunar.getSolar();
      return LunarResolution(
        solarDate: DateTime(solar.getYear(), solar.getMonth(), solar.getDay()),
        lunarYear: lunarYear,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  LunarDate? toLunar(DateTime date) {
    try {
      final Lunar lunar = Solar.fromYmd(
        date.year,
        date.month,
        date.day,
      ).getLunar();
      final int month = lunar.getMonth();
      return LunarDate(
        year: lunar.getYear(),
        month: month.abs(),
        day: lunar.getDay(),
        isLeapMonth: month < 0,
        monthName: lunar.getMonthInChinese(),
        dayName: lunar.getDayInChinese(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// 不支持农历时的降级实现（仅用于测试或裁剪版本）。
class NoLunarConverter implements LunarConverter {
  const NoLunarConverter();

  @override
  bool get isAvailable => false;

  @override
  LunarResolution? resolve({
    required int month,
    required int day,
    required int lunarYear,
    bool isLeapMonth = false,
  }) => null;

  @override
  LunarDate? toLunar(DateTime date) => null;
}
