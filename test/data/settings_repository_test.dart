import 'dart:io';

import 'package:birthday_keeper/data/json_settings_repository.dart';
import 'package:birthday_keeper/data/json_store.dart';
import 'package:birthday_keeper/data/settings_repository.dart';
import 'package:birthday_keeper/models/app_settings.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemorySettingsRepository', () {
    test('默认返回 AppSettings 默认值', () async {
      final InMemorySettingsRepository repository =
          InMemorySettingsRepository();
      expect(await repository.load(), const AppSettings());
    });

    test('保存后能读回', () async {
      final InMemorySettingsRepository repository =
          InMemorySettingsRepository();
      const AppSettings settings = AppSettings(
        notificationsEnabled: false,
        sortMode: ContactSortMode.name,
      );
      await repository.save(settings);
      expect(await repository.load(), settings);
    });
  });

  group('JsonSettingsRepository', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bk_settings');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    JsonStore store([String name = 'settings.json']) =>
        JsonStore(resolveFile: () async => File('${tempDir.path}/$name'));

    test('文件不存在时返回默认设置', () async {
      expect(
        await JsonSettingsRepository(store: store()).load(),
        const AppSettings(),
      );
    });

    test('往返一致', () async {
      final JsonSettingsRepository repository = JsonSettingsRepository(
        store: store(),
      );
      const AppSettings settings = AppSettings(
        notificationsEnabled: false,
        defaultReminder: ReminderSettings(
          daysBefore: 5,
          notifyOnDay: false,
          hour: 18,
          minute: 30,
        ),
        sortMode: ContactSortMode.recentlyUpdated,
        showLunarInfo: false,
        groupUpcoming: false,
      );
      await repository.save(settings);
      expect(await repository.load(), settings);
    });

    test('文件损坏时回退到默认设置', () async {
      await File('${tempDir.path}/settings.json').writeAsString('not json');
      expect(
        await JsonSettingsRepository(store: store()).load(),
        const AppSettings(),
      );
    });

    test('settings 字段类型不对时回退到默认设置', () async {
      await store().write(<String, Object?>{'settings': 42});
      expect(
        await JsonSettingsRepository(store: store()).load(),
        const AppSettings(),
      );
    });
  });
}
