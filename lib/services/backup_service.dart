import 'dart:convert';

import 'package:meta/meta.dart';

import '../models/app_settings.dart';
import '../models/contact.dart';

/// 一次备份的内容。
@immutable
class BackupPayload {
  const BackupPayload({required this.contacts, required this.settings});

  final List<Contact> contacts;
  final AppSettings settings;
}

/// 数据导出 / 导入。
///
/// 刻意做成纯函数式的字符串处理：不依赖文件选择器或分享插件，
/// 因此可以被完整单测，也不会给安装包增加原生依赖。
class BackupService {
  const BackupService();

  static const String formatTag = 'birthdayKeeper';
  static const int schemaVersion = 1;

  /// 导出为格式化后的 JSON 文本。
  String exportToJson({
    required List<Contact> contacts,
    required AppSettings settings,
    DateTime? now,
  }) => const JsonEncoder.withIndent('  ').convert(<String, Object?>{
    'format': formatTag,
    'schemaVersion': schemaVersion,
    'exportedAt': (now ?? DateTime.now()).toIso8601String(),
    'settings': settings.toJson(),
    'contacts': contacts.map((Contact c) => c.toJson()).toList(),
  });

  /// 解析备份文本；格式不对时抛出 [FormatException]。
  BackupPayload parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('内容不是合法的 JSON');
    }
    if (decoded is! Map) {
      throw const FormatException('备份内容格式不正确');
    }
    final Map<String, Object?> map = decoded.cast<String, Object?>();
    if (map['format'] != formatTag) {
      throw const FormatException('这不是「生日管家」导出的备份');
    }
    final Object? rawContacts = map['contacts'];
    if (rawContacts is! List) {
      throw const FormatException('备份里没有联系人数据');
    }

    final List<Contact> contacts = <Contact>[];
    for (final Object? item in rawContacts) {
      if (item is! Map) continue;
      try {
        contacts.add(Contact.fromJson(item.cast<String, Object?>()));
      } on Object {
        // 同样的原则：单条坏数据只跳过它自己。
        continue;
      }
    }

    final Object? rawSettings = map['settings'];
    final AppSettings settings = rawSettings is Map
        ? AppSettings.fromJson(rawSettings.cast<String, Object?>())
        : const AppSettings();

    return BackupPayload(contacts: contacts, settings: settings);
  }
}
