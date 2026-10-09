import 'package:meta/meta.dart';

import 'contact.dart';

/// 联系人列表的排序方式。
enum ContactSortMode {
  daysUntil('按生日临近'),
  name('按姓名'),
  recentlyUpdated('按最近修改');

  const ContactSortMode(this.label);

  final String label;

  static ContactSortMode fromName(String? name) {
    for (final ContactSortMode value in ContactSortMode.values) {
      if (value.name == name) return value;
    }
    return ContactSortMode.daysUntil;
  }
}

/// 全局设置。
@immutable
class AppSettings {
  const AppSettings({
    this.notificationsEnabled = true,
    this.defaultReminder = const ReminderSettings(),
    this.sortMode = ContactSortMode.daysUntil,
    this.showLunarInfo = true,
    this.groupUpcoming = true,
  });

  /// 总开关：关闭后不再调度任何通知。
  final bool notificationsEnabled;

  /// 新建联系人时使用的默认提醒设置（默认提前 3 天 + 当天，09:00）。
  final ReminderSettings defaultReminder;

  final ContactSortMode sortMode;

  /// 是否在详情页展示农历信息。
  final bool showLunarInfo;

  /// 「即将到来」页是否按时间分组展示。
  final bool groupUpcoming;

  AppSettings copyWith({
    bool? notificationsEnabled,
    ReminderSettings? defaultReminder,
    ContactSortMode? sortMode,
    bool? showLunarInfo,
    bool? groupUpcoming,
  }) => AppSettings(
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    defaultReminder: defaultReminder ?? this.defaultReminder,
    sortMode: sortMode ?? this.sortMode,
    showLunarInfo: showLunarInfo ?? this.showLunarInfo,
    groupUpcoming: groupUpcoming ?? this.groupUpcoming,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'notificationsEnabled': notificationsEnabled,
    'defaultReminder': defaultReminder.toJson(),
    'sortMode': sortMode.name,
    'showLunarInfo': showLunarInfo,
    'groupUpcoming': groupUpcoming,
  };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    const AppSettings fallback = AppSettings();
    final Object? defaultReminder = json['defaultReminder'];
    final Object? sortMode = json['sortMode'];
    final Object? notificationsEnabled = json['notificationsEnabled'];
    final Object? showLunarInfo = json['showLunarInfo'];
    final Object? groupUpcoming = json['groupUpcoming'];
    return AppSettings(
      notificationsEnabled: notificationsEnabled is bool
          ? notificationsEnabled
          : fallback.notificationsEnabled,
      defaultReminder: defaultReminder is Map
          ? ReminderSettings.fromJson(defaultReminder.cast<String, Object?>())
          : fallback.defaultReminder,
      sortMode: sortMode is String
          ? ContactSortMode.fromName(sortMode)
          : fallback.sortMode,
      showLunarInfo: showLunarInfo is bool
          ? showLunarInfo
          : fallback.showLunarInfo,
      groupUpcoming: groupUpcoming is bool
          ? groupUpcoming
          : fallback.groupUpcoming,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          other.notificationsEnabled == notificationsEnabled &&
          other.defaultReminder == defaultReminder &&
          other.sortMode == sortMode &&
          other.showLunarInfo == showLunarInfo &&
          other.groupUpcoming == groupUpcoming;

  @override
  int get hashCode => Object.hash(
    notificationsEnabled,
    defaultReminder,
    sortMode,
    showLunarInfo,
    groupUpcoming,
  );
}
