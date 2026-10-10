import 'package:meta/meta.dart';

import 'birthday.dart';
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
    this.showTipCard = true,
    this.hiddenTipIds = const <String>[],
    this.importCalendar = BirthdayCalendar.solar,
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

  /// 是否在首页显示「使用提示」卡片。
  final bool showTipCard;

  /// 被用户「不再提示」的提示 id。
  final List<String> hiddenTipIds;

  /// 文本导入时，没有写明历法的日期按哪种历法理解（默认新历）。
  ///
  /// 另外解析器还有一条「文档级推断」：整段文本只要出现过「农历」字样，
  /// 没标注的日期就按新历算 —— 因为会写「农历」的人一定是显式标注的。
  final BirthdayCalendar importCalendar;

  bool isTipHidden(String id) => hiddenTipIds.contains(id);

  AppSettings copyWith({
    bool? notificationsEnabled,
    ReminderSettings? defaultReminder,
    ContactSortMode? sortMode,
    bool? showLunarInfo,
    bool? groupUpcoming,
    bool? showTipCard,
    List<String>? hiddenTipIds,
    BirthdayCalendar? importCalendar,
  }) => AppSettings(
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    defaultReminder: defaultReminder ?? this.defaultReminder,
    sortMode: sortMode ?? this.sortMode,
    showLunarInfo: showLunarInfo ?? this.showLunarInfo,
    groupUpcoming: groupUpcoming ?? this.groupUpcoming,
    showTipCard: showTipCard ?? this.showTipCard,
    hiddenTipIds: hiddenTipIds ?? this.hiddenTipIds,
    importCalendar: importCalendar ?? this.importCalendar,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'notificationsEnabled': notificationsEnabled,
    'defaultReminder': defaultReminder.toJson(),
    'sortMode': sortMode.name,
    'showLunarInfo': showLunarInfo,
    'groupUpcoming': groupUpcoming,
    'showTipCard': showTipCard,
    'hiddenTipIds': hiddenTipIds,
    'importCalendar': importCalendar.name,
  };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    const AppSettings fallback = AppSettings();
    final Object? defaultReminder = json['defaultReminder'];
    final Object? sortMode = json['sortMode'];
    final Object? notificationsEnabled = json['notificationsEnabled'];
    final Object? showLunarInfo = json['showLunarInfo'];
    final Object? groupUpcoming = json['groupUpcoming'];
    final Object? showTipCard = json['showTipCard'];
    final Object? hiddenTipIds = json['hiddenTipIds'];
    final Object? importCalendar = json['importCalendar'];
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
      showTipCard: showTipCard is bool ? showTipCard : fallback.showTipCard,
      hiddenTipIds: hiddenTipIds is List
          ? hiddenTipIds.whereType<String>().toList()
          : fallback.hiddenTipIds,
      importCalendar: importCalendar is String
          ? BirthdayCalendar.fromName(importCalendar)
          : fallback.importCalendar,
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
          other.groupUpcoming == groupUpcoming &&
          other.showTipCard == showTipCard &&
          _sameList(other.hiddenTipIds, hiddenTipIds) &&
          other.importCalendar == importCalendar;

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    notificationsEnabled,
    defaultReminder,
    sortMode,
    showLunarInfo,
    groupUpcoming,
    showTipCard,
    Object.hashAll(hiddenTipIds),
    importCalendar,
  );
}
