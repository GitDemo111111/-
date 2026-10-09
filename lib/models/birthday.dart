import 'package:meta/meta.dart';

import '../core/date_x.dart';

/// 生日所使用的历法。
enum BirthdayCalendar {
  /// 新历（也叫公历 / 阳历）。界面上统一叫「新历」。
  solar('新历'),
  lunar('农历');

  const BirthdayCalendar(this.label);

  /// 界面上展示的名称。
  final String label;

  static BirthdayCalendar fromName(String? name) {
    for (final BirthdayCalendar value in BirthdayCalendar.values) {
      if (value.name == name) return value;
    }
    return BirthdayCalendar.solar;
  }
}

/// 校验「年份未知」的生日时使用的参考年份。
///
/// 取闰年，这样 2 月 29 日会被认为是合法输入。
const int kReferenceLeapYear = 2024;

/// 一个「生日」值对象。
///
/// 生日天然只有月和日；年份是可选的，因为很多人并不清楚（或不方便记录）
/// 对方的出生年份。年份缺失时，所有和年龄有关的展示都会自动隐藏。
@immutable
class Birthday {
  const Birthday({
    required this.month,
    required this.day,
    this.year,
    this.calendar = BirthdayCalendar.solar,
    this.isLeapMonth = false,
  });

  final int month;
  final int day;
  final int? year;
  final BirthdayCalendar calendar;

  /// 仅农历有意义：该生日是否落在闰月。
  final bool isLeapMonth;

  bool get hasYear => year != null;
  bool get isSolar => calendar == BirthdayCalendar.solar;
  bool get isLunar => calendar == BirthdayCalendar.lunar;

  /// 公历 2 月 29 日 —— 平年时需要特殊处理。
  bool get isSolarLeapDay => isSolar && month == 2 && day == 29;

  /// 只保留月日。
  Birthday withoutYear() => Birthday(
    month: month,
    day: day,
    calendar: calendar,
    isLeapMonth: isLeapMonth,
  );

  /// 校验当前值，返回中文错误提示；`null` 表示合法。
  String? validate() {
    if (month < 1 || month > 12) return '月份需要在 1 到 12 之间';
    if (day < 1) return '日期不能小于 1';
    if (isSolar) {
      if (year != null && (year! < 1900 || year! > 2100)) {
        return '年份需要在 1900 到 2100 之间';
      }
      final int maxDay = daysInSolarMonth(year ?? kReferenceLeapYear, month);
      if (day > maxDay) return '$month 月最多只有 $maxDay 天';
    } else {
      if (day > 30) return '农历一个月最多只有 30 天';
      if (year != null && (year! < 1900 || year! > 2100)) {
        return '年份需要在 1900 到 2100 之间';
      }
    }
    return null;
  }

  bool get isValid => validate() == null;

  /// 带年份的展示文本，例如 `1995年5月20日` / `农历闰4月初八`。
  String get displayLabel {
    final StringBuffer buffer = StringBuffer();
    if (isLunar) buffer.write('农历');
    if (year != null) buffer.write('$year年');
    if (isLunar && isLeapMonth) buffer.write('闰');
    buffer.write('$month月$day日');
    return buffer.toString();
  }

  /// 不带年份的展示文本，例如 `5月20日`。
  String get shortLabel {
    final StringBuffer buffer = StringBuffer();
    if (isLunar) buffer.write('农历');
    if (isLunar && isLeapMonth) buffer.write('闰');
    buffer.write('$month月$day日');
    return buffer.toString();
  }

  /// 若年份已知，返回对应的公历日期（仅对公历生日有意义）。
  DateTime? get asDateTime =>
      year == null || !isSolar ? null : DateTime(year!, month, day);

  Birthday copyWith({
    int? month,
    int? day,
    int? year,
    BirthdayCalendar? calendar,
    bool? isLeapMonth,
  }) => Birthday(
    month: month ?? this.month,
    day: day ?? this.day,
    year: year ?? this.year,
    calendar: calendar ?? this.calendar,
    isLeapMonth: isLeapMonth ?? this.isLeapMonth,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'month': month,
    'day': day,
    if (year != null) 'year': year,
    'calendar': calendar.name,
    if (isLeapMonth) 'isLeapMonth': true,
  };

  /// 从 JSON 还原。数据损坏时抛出 [FormatException]，由仓储层决定如何降级。
  factory Birthday.fromJson(Map<String, Object?> json) {
    final Object? month = json['month'];
    final Object? day = json['day'];
    if (month is! int || day is! int) {
      throw const FormatException('生日数据缺少 month/day');
    }
    final Object? year = json['year'];
    final Object? calendar = json['calendar'];
    return Birthday(
      month: month,
      day: day,
      year: year is int ? year : null,
      calendar: calendar is String
          ? BirthdayCalendar.fromName(calendar)
          : BirthdayCalendar.solar,
      isLeapMonth: json['isLeapMonth'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Birthday &&
          other.month == month &&
          other.day == day &&
          other.year == year &&
          other.calendar == calendar &&
          other.isLeapMonth == isLeapMonth;

  @override
  int get hashCode => Object.hash(month, day, year, calendar, isLeapMonth);

  @override
  String toString() => 'Birthday($displayLabel)';
}
