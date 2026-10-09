import 'package:meta/meta.dart';

import '../models/birthday.dart';
import '../models/contact.dart';
import 'astrology.dart';
import 'date_x.dart';
import 'formatters.dart';
import 'lunar_converter.dart';

/// 某个生日在具体某一年落到的公历日期。
@immutable
class BirthdayOccurrence {
  const BirthdayOccurrence({
    required this.date,
    required this.yearForAge,
    this.lunarDate,
  });

  /// 公历日期（只精确到天）。
  final DateTime date;

  /// 计算年龄时使用的「年」：公历生日用公历年，农历生日用对应的农历年。
  final int? yearForAge;

  /// 农历生日时，对应的农历日期。
  final LunarDate? lunarDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BirthdayOccurrence && other.date == date;

  @override
  int get hashCode => date.hashCode;

  @override
  String toString() => 'BirthdayOccurrence(${formatIsoDate(date)})';
}

/// 生日计算的唯一入口。
///
/// 这里刻意做成纯计算、无副作用、可注入 [LunarConverter] 的形式，
/// 所以几乎所有的边界情况（2 月 29 日、跨年、农历闰月）都能被单测覆盖。
class BirthdayCalculator {
  const BirthdayCalculator({
    this.lunarConverter = const LunarPackageConverter(),
  });

  final LunarConverter lunarConverter;

  /// 是否支持农历生日。
  bool get supportsLunar => lunarConverter.isAvailable;

  /// 计算 [birthday] 归属到第 [year] 个「生日周期」的公历日期。
  ///
  /// - 公历生日：[year] 就是公历年。
  /// - 农历生日：[year] 是**农历年**，换算出的公历日期可能落在同一年，
  ///   也可能落在下一年的 1、2 月。
  ///
  /// 农历生日无法换算时返回 `null`。
  BirthdayOccurrence? occurrenceInYear(Birthday birthday, int year) {
    if (birthday.isSolar) {
      // safeDate 会把平年的 2 月 29 日收缩到 2 月 28 日。
      final DateTime date = safeDate(year, birthday.month, birthday.day);
      return BirthdayOccurrence(date: date, yearForAge: year);
    }
    final LunarResolution? resolution = lunarConverter.resolve(
      month: birthday.month,
      day: birthday.day,
      lunarYear: year,
      isLeapMonth: birthday.isLeapMonth,
    );
    if (resolution == null) return null;
    return BirthdayOccurrence(
      date: resolution.solarDate,
      yearForAge: resolution.lunarYear,
      lunarDate: lunarConverter.toLunar(resolution.solarDate),
    );
  }

  /// 从 [from] 当天（含）开始的下一个生日。
  ///
  /// 今天就是生日时返回今天。
  BirthdayOccurrence? nextOccurrence(Birthday birthday, DateTime from) {
    final DateTime today = dateOnly(from);
    // 公历生日从今年开始找即可；农历生日要多回看一年 —— 农历一年比公历
    // 一年短，所以「上一个农历年的同一个月日」有可能晚于今天。
    final int startYear = today.year - (birthday.isSolar ? 0 : 1);
    BirthdayOccurrence? best;
    for (int offset = 0; offset <= 3; offset++) {
      final BirthdayOccurrence? occurrence = occurrenceInYear(
        birthday,
        startYear + offset,
      );
      if (occurrence == null) continue;
      if (occurrence.date.isBefore(today)) continue;
      if (best == null || occurrence.date.isBefore(best.date)) {
        best = occurrence;
      }
    }
    return best;
  }

  /// 从 [from] 开始，接下来 [count] 次生日。
  List<BirthdayOccurrence> nextOccurrences(
    Birthday birthday,
    DateTime from,
    int count,
  ) {
    final List<BirthdayOccurrence> result = <BirthdayOccurrence>[];
    DateTime cursor = dateOnly(from);
    for (int i = 0; i < count; i++) {
      final BirthdayOccurrence? occurrence = nextOccurrence(birthday, cursor);
      if (occurrence == null) break;
      result.add(occurrence);
      // 从生日的第二天继续找，避免重复命中同一天。
      cursor = DateTime(
        occurrence.date.year,
        occurrence.date.month,
        occurrence.date.day + 1,
      );
    }
    return result;
  }

  /// 距离下一个生日还有多少天。今天生日返回 0。
  int? daysUntil(Birthday birthday, DateTime from) {
    final BirthdayOccurrence? occurrence = nextOccurrence(birthday, from);
    if (occurrence == null) return null;
    return daysBetween(from, occurrence.date);
  }

  /// 在某一次生日时将满多少岁。出生年份未知时返回 `null`。
  int? ageAt(Birthday birthday, BirthdayOccurrence occurrence) {
    final int? birthYear = birthday.year;
    final int? yearForAge = occurrence.yearForAge;
    if (birthYear == null || yearForAge == null) return null;
    final int age = yearForAge - birthYear;
    return age < 0 ? null : age;
  }

  /// 下一个生日时将满多少岁。出生年份未知时返回 `null`。
  int? turningAge(Birthday birthday, DateTime from) {
    final BirthdayOccurrence? occurrence = nextOccurrence(birthday, from);
    if (occurrence == null) return null;
    return ageAt(birthday, occurrence);
  }

  /// 当前年龄（还没过生日就是「将满年龄 - 1」）。
  int? currentAge(Birthday birthday, DateTime from) {
    final int? turning = turningAge(birthday, from);
    if (turning == null) return null;
    final int? days = daysUntil(birthday, from);
    if (days == null) return null;
    return days == 0 ? turning : (turning - 1).clamp(0, 200).toInt();
  }

  /// 下一个生日是否就是今天。
  bool isBirthdayToday(Birthday birthday, DateTime from) =>
      daysUntil(birthday, from) == 0;

  /// 星座（按公历日期判断）。
  String? constellation(Birthday birthday, DateTime from) {
    final BirthdayOccurrence? occurrence = nextOccurrence(birthday, from);
    if (occurrence == null) return null;
    return constellationOf(occurrence.date.month, occurrence.date.day);
  }

  /// 生肖（需要知道出生年份）。
  String? chineseZodiac(Birthday birthday) {
    final int? year = birthday.year;
    if (year == null) return null;
    // 农历生日的生肖以农历年为准。
    return chineseZodiacOf(year);
  }

  /// 该生日在 [from] 这一天的农历表述（用于详情页展示）。
  LunarDate? lunarDateOf(DateTime date) => lunarConverter.toLunar(date);
}

/// 一位联系人 + 他/她即将到来的生日。
@immutable
class UpcomingBirthday {
  const UpcomingBirthday({
    required this.contact,
    required this.occurrence,
    required this.daysUntil,
    this.turningAge,
  });

  final Contact contact;
  final BirthdayOccurrence occurrence;
  final int daysUntil;

  /// 将满多少岁；出生年份未知时为 `null`。
  final int? turningAge;

  DateTime get date => occurrence.date;

  bool get isToday => daysUntil == 0;
  bool get isTomorrow => daysUntil == 1;

  /// `今天` / `3天后`。
  String get countdownLabel => relativeDayLabel(daysUntil);

  @override
  String toString() => 'UpcomingBirthday(${contact.name}, $countdownLabel)';
}
