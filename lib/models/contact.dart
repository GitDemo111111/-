import 'package:meta/meta.dart';

import '../core/date_x.dart';
import 'birthday.dart';
import 'relationship.dart';

/// 用于 [Contact.copyWith] 中区分「不修改」与「显式置空」。
const Object _unset = Object();

/// 取字符串的第一个「字」；遇到代理对（例如 emoji）时整体取出。
String _firstGlyph(String value) {
  if (value.isEmpty) return '';
  final int first = value.codeUnitAt(0);
  final bool isHighSurrogate = first >= 0xD800 && first <= 0xDBFF;
  if (isHighSurrogate && value.length >= 2) return value.substring(0, 2);
  return value.substring(0, 1);
}

/// 单个联系人的提醒设置。
@immutable
class ReminderSettings {
  const ReminderSettings({
    this.enabled = true,
    this.daysBefore = defaultDaysBefore,
    this.notifyOnDay = true,
    this.hour = defaultHour,
    this.minute = defaultMinute,
  });

  /// 默认提前 3 天提醒。
  static const int defaultDaysBefore = 3;
  static const int defaultHour = 9;
  static const int defaultMinute = 0;

  static const int minDaysBefore = 0;
  static const int maxDaysBefore = 60;

  /// 是否为此联系人开启提醒。
  final bool enabled;

  /// 提前多少天提醒。
  final int daysBefore;

  /// 生日当天是否也要提醒。
  final bool notifyOnDay;

  /// 提醒时间（24 小时制）。
  final int hour;
  final int minute;

  String get timeLabel => '${twoDigits(hour)}:${twoDigits(minute)}';

  /// 一句话描述提醒方式，例如 `提前3天 + 当天 09:00`。
  String get summary {
    if (!enabled) return '已关闭提醒';
    final List<String> parts = <String>[
      if (daysBefore > 0) '提前$daysBefore天',
      if (notifyOnDay) '当天',
    ];
    if (parts.isEmpty) return '不提醒';
    return '${parts.join(' + ')} $timeLabel';
  }

  ReminderSettings copyWith({
    bool? enabled,
    int? daysBefore,
    bool? notifyOnDay,
    int? hour,
    int? minute,
  }) => ReminderSettings(
    enabled: enabled ?? this.enabled,
    daysBefore: (daysBefore ?? this.daysBefore)
        .clamp(minDaysBefore, maxDaysBefore)
        .toInt(),
    notifyOnDay: notifyOnDay ?? this.notifyOnDay,
    hour: (hour ?? this.hour).clamp(0, 23).toInt(),
    minute: (minute ?? this.minute).clamp(0, 59).toInt(),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'daysBefore': daysBefore,
    'notifyOnDay': notifyOnDay,
    'hour': hour,
    'minute': minute,
  };

  factory ReminderSettings.fromJson(Map<String, Object?> json) {
    const ReminderSettings fallback = ReminderSettings();
    final Object? enabled = json['enabled'];
    final Object? daysBefore = json['daysBefore'];
    final Object? notifyOnDay = json['notifyOnDay'];
    final Object? hour = json['hour'];
    final Object? minute = json['minute'];
    return ReminderSettings(
      enabled: enabled is bool ? enabled : fallback.enabled,
      daysBefore: daysBefore is int
          ? daysBefore.clamp(minDaysBefore, maxDaysBefore).toInt()
          : fallback.daysBefore,
      notifyOnDay: notifyOnDay is bool ? notifyOnDay : fallback.notifyOnDay,
      hour: hour is int ? hour.clamp(0, 23).toInt() : fallback.hour,
      minute: minute is int ? minute.clamp(0, 59).toInt() : fallback.minute,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderSettings &&
          other.enabled == enabled &&
          other.daysBefore == daysBefore &&
          other.notifyOnDay == notifyOnDay &&
          other.hour == hour &&
          other.minute == minute;

  @override
  int get hashCode =>
      Object.hash(enabled, daysBefore, notifyOnDay, hour, minute);
}

/// 一位联系人。
///
/// 只有 [name] 是必填的，其它字段（关系、生日、爱好、联系方式……）都可以留空。
@immutable
class Contact {
  const Contact({
    required this.id,
    required this.name,
    this.relationship,
    this.relationLabel,
    this.birthday,
    this.hobbies = const <String>[],
    this.tags = const <String>[],
    this.phone,
    this.email,
    this.wechat,
    this.address,
    this.notes,
    this.giftIdeas,
    this.avatarEmoji,
    this.colorSeed = 0,
    this.favorite = false,
    this.reminder = const ReminderSettings(),
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;

  /// 内置的关系/身份选项，可以为空。
  final Relationship? relationship;

  /// 自定义的身份/称呼，例如「大学室友」。可以为空。
  final String? relationLabel;

  /// 生日，可以为空。
  final Birthday? birthday;

  /// 爱好标签，可以为空。
  final List<String> hobbies;

  /// 自定义标签，可以为空。
  final List<String> tags;

  final String? phone;
  final String? email;
  final String? wechat;
  final String? address;
  final String? notes;

  /// 礼物灵感。
  final String? giftIdeas;

  /// 头像上显示的 emoji；为空时用姓名首字。
  final String? avatarEmoji;

  /// 用于挑选头像底色的种子，保证同一个人的颜色稳定。
  final int colorSeed;

  final bool favorite;

  final ReminderSettings reminder;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasBirthday => birthday != null;

  /// 头像上显示的字符。
  String get initial {
    final String trimmed = name.trim();
    return trimmed.isEmpty ? '?' : _firstGlyph(trimmed);
  }

  /// 关系标签的组合展示，例如「家人 · 母亲」。
  String? get relationshipLabel {
    final String? custom = _trimmed(relationLabel);
    if (relationship == null && custom == null) return null;
    if (relationship == null) return custom;
    if (custom == null) return relationship!.label;
    if (custom == relationship!.label) return custom;
    return '${relationship!.label} · $custom';
  }

  /// 用于搜索的小写文本。
  String get searchText => <String>[
    name,
    ?relationship?.label,
    ?relationLabel,
    ...hobbies,
    ...tags,
    ?notes,
    ?giftIdeas,
    ?phone,
    ?wechat,
    ?email,
  ].join(' ').toLowerCase();

  /// 除 id / 时间戳 / 提醒设置以外的信息是否完全一致。
  ///
  /// 用于导入时判断「重复联系人」：同名且内容一致 -> 自动合并，不再新增一条。
  /// 爱好、标签按集合比较，顺序不同也算一致。
  bool hasSameContent(Contact other) {
    bool sameSet(List<String> a, List<String> b) {
      if (a.length != b.length) return false;
      for (final String item in a) {
        if (!b.contains(item)) return false;
      }
      return true;
    }

    return _trimmed(name)?.toLowerCase() ==
            _trimmed(other.name)?.toLowerCase() &&
        birthday == other.birthday &&
        relationship == other.relationship &&
        _trimmed(relationLabel) == _trimmed(other.relationLabel) &&
        sameSet(hobbies, other.hobbies) &&
        sameSet(tags, other.tags) &&
        _trimmed(phone) == _trimmed(other.phone) &&
        _trimmed(email) == _trimmed(other.email) &&
        _trimmed(wechat) == _trimmed(other.wechat) &&
        _trimmed(address) == _trimmed(other.address) &&
        _trimmed(notes) == _trimmed(other.notes) &&
        _trimmed(giftIdeas) == _trimmed(other.giftIdeas) &&
        _trimmed(avatarEmoji) == _trimmed(other.avatarEmoji);
  }

  static String? _trimmed(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Contact copyWith({
    String? id,
    String? name,
    Object? relationship = _unset,
    Object? relationLabel = _unset,
    Object? birthday = _unset,
    List<String>? hobbies,
    List<String>? tags,
    Object? phone = _unset,
    Object? email = _unset,
    Object? wechat = _unset,
    Object? address = _unset,
    Object? notes = _unset,
    Object? giftIdeas = _unset,
    Object? avatarEmoji = _unset,
    int? colorSeed,
    bool? favorite,
    ReminderSettings? reminder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Contact(
    id: id ?? this.id,
    name: name ?? this.name,
    relationship: relationship == _unset
        ? this.relationship
        : relationship as Relationship?,
    relationLabel: relationLabel == _unset
        ? this.relationLabel
        : relationLabel as String?,
    birthday: birthday == _unset ? this.birthday : birthday as Birthday?,
    hobbies: hobbies ?? this.hobbies,
    tags: tags ?? this.tags,
    phone: phone == _unset ? this.phone : phone as String?,
    email: email == _unset ? this.email : email as String?,
    wechat: wechat == _unset ? this.wechat : wechat as String?,
    address: address == _unset ? this.address : address as String?,
    notes: notes == _unset ? this.notes : notes as String?,
    giftIdeas: giftIdeas == _unset ? this.giftIdeas : giftIdeas as String?,
    avatarEmoji: avatarEmoji == _unset
        ? this.avatarEmoji
        : avatarEmoji as String?,
    colorSeed: colorSeed ?? this.colorSeed,
    favorite: favorite ?? this.favorite,
    reminder: reminder ?? this.reminder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() {
    final String? relationLabelValue = _trimmed(relationLabel);
    final String? phoneValue = _trimmed(phone);
    final String? emailValue = _trimmed(email);
    final String? wechatValue = _trimmed(wechat);
    final String? addressValue = _trimmed(address);
    final String? notesValue = _trimmed(notes);
    final String? giftIdeasValue = _trimmed(giftIdeas);
    final String? avatarEmojiValue = _trimmed(avatarEmoji);
    return <String, Object?>{
      'id': id,
      'name': name,
      'relationship': ?relationship?.name,
      'relationLabel': ?relationLabelValue,
      'birthday': ?birthday?.toJson(),
      if (hobbies.isNotEmpty) 'hobbies': hobbies,
      if (tags.isNotEmpty) 'tags': tags,
      'phone': ?phoneValue,
      'email': ?emailValue,
      'wechat': ?wechatValue,
      'address': ?addressValue,
      'notes': ?notesValue,
      'giftIdeas': ?giftIdeasValue,
      'avatarEmoji': ?avatarEmojiValue,
      'colorSeed': colorSeed,
      'favorite': favorite,
      'reminder': reminder.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// 从 JSON 还原；缺少 `id`/`name` 时抛出 [FormatException]。
  ///
  /// 其它字段类型不对时一律退化为「未填写」，而不是抛异常 —— 一个坏字段
  /// 不应该让整份本地数据读不出来。
  factory Contact.fromJson(Map<String, Object?> json) {
    final Object? id = json['id'];
    final Object? name = json['name'];
    if (id is! String || name is! String) {
      throw const FormatException('联系人数据缺少 id 或 name');
    }
    final Object? birthday = json['birthday'];
    final Object? reminder = json['reminder'];
    final Object? colorSeed = json['colorSeed'];
    return Contact(
      id: id,
      name: name,
      relationship: Relationship.fromName(_asString(json['relationship'])),
      relationLabel: _asString(json['relationLabel']),
      birthday: birthday is Map
          ? Birthday.fromJson(birthday.cast<String, Object?>())
          : null,
      hobbies: _stringList(json['hobbies']),
      tags: _stringList(json['tags']),
      phone: _asString(json['phone']),
      email: _asString(json['email']),
      wechat: _asString(json['wechat']),
      address: _asString(json['address']),
      notes: _asString(json['notes']),
      giftIdeas: _asString(json['giftIdeas']),
      avatarEmoji: _asString(json['avatarEmoji']),
      colorSeed: colorSeed is int ? colorSeed : 0,
      favorite: json['favorite'] == true,
      reminder: reminder is Map
          ? ReminderSettings.fromJson(reminder.cast<String, Object?>())
          : const ReminderSettings(),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt']) ?? DateTime.now(),
    );
  }

  static String? _asString(Object? value) => value is String ? value : null;

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<String>()
        .where((String element) => element.trim().isNotEmpty)
        .toList();
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  /// 联系人按 `id` 判定为同一个实体。
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Contact && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Contact($id, $name)';
}
