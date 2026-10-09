import 'dart:convert';

import 'package:web/web.dart' as web;

import '../models/app_settings.dart';
import '../models/contact.dart';
import 'contact_repository.dart';
import 'settings_repository.dart';

/// Web 预览版的存储：直接读写浏览器的 localStorage。
///
/// 手机端把 JSON 写进文件（[JsonStore]）；浏览器里没有文件系统，所以换成
/// localStorage —— 这样在网页里添加的联系人刷新之后依然还在。
class WebKeyValueStore {
  const WebKeyValueStore();

  Map<String, Object?>? read(String key) {
    final String? raw = web.window.localStorage.getItem(key);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, Object?>() : null;
    } on FormatException {
      // 数据坏了就当没有，不要让页面白屏。
      return null;
    }
  }

  void write(String key, Map<String, Object?> data) {
    web.window.localStorage.setItem(key, jsonEncode(data));
  }
}

/// localStorage 版本的联系人仓储。
class WebContactRepository implements ContactRepository {
  WebContactRepository({WebKeyValueStore? store})
    : _store = store ?? const WebKeyValueStore();

  static const int schemaVersion = 1;
  static const String storageKey = 'birthday_keeper.contacts';

  final WebKeyValueStore _store;

  @override
  Future<List<Contact>> load() async {
    final Map<String, Object?>? data = _store.read(storageKey);
    if (data == null) return <Contact>[];
    final Object? raw = data['contacts'];
    if (raw is! List) return <Contact>[];
    final List<Contact> result = <Contact>[];
    for (final Object? item in raw) {
      if (item is! Map) continue;
      try {
        result.add(Contact.fromJson(item.cast<String, Object?>()));
      } on Object {
        // 和文件版一样：单条坏数据只跳过它自己。
        continue;
      }
    }
    return result;
  }

  @override
  Future<void> save(List<Contact> contacts) async {
    _store.write(storageKey, <String, Object?>{
      'schemaVersion': schemaVersion,
      'contacts': contacts.map((Contact c) => c.toJson()).toList(),
    });
  }
}

/// localStorage 版本的设置仓储。
class WebSettingsRepository implements SettingsRepository {
  WebSettingsRepository({WebKeyValueStore? store})
    : _store = store ?? const WebKeyValueStore();

  static const int schemaVersion = 1;
  static const String storageKey = 'birthday_keeper.settings';

  final WebKeyValueStore _store;

  @override
  Future<AppSettings> load() async {
    final Map<String, Object?>? data = _store.read(storageKey);
    if (data == null) return const AppSettings();
    final Object? raw = data['settings'];
    if (raw is! Map) return const AppSettings();
    try {
      return AppSettings.fromJson(raw.cast<String, Object?>());
    } on Object {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    _store.write(storageKey, <String, Object?>{
      'schemaVersion': schemaVersion,
      'settings': settings.toJson(),
    });
  }
}
