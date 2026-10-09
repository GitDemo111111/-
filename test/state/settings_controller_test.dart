import 'package:birthday_keeper/data/settings_repository.dart';
import 'package:birthday_keeper/models/app_settings.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/state/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySettingsRepository repository;
  late SettingsController controller;

  setUp(() {
    repository = InMemorySettingsRepository();
    controller = SettingsController(repository: repository);
  });

  test('初始状态未加载，使用默认设置', () {
    expect(controller.isLoaded, isFalse);
    expect(controller.settings, const AppSettings());
  });

  test('load 会读取仓储并标记已加载', () async {
    repository = InMemorySettingsRepository(
      const AppSettings(sortMode: ContactSortMode.name),
    );
    controller = SettingsController(repository: repository);

    await controller.load();
    expect(controller.isLoaded, isTrue);
    expect(controller.settings.sortMode, ContactSortMode.name);
  });

  test('update 会写回仓储并通知监听者', () async {
    int notifications = 0;
    controller.addListener(() => notifications++);

    const AppSettings next = AppSettings(showLunarInfo: false);
    await controller.update(next);

    expect(controller.settings, next);
    expect(await repository.load(), next);
    expect(notifications, 1);
  });

  test('update 传入相同设置时不重复通知与写盘', () async {
    await controller.load();
    int notifications = 0;
    controller.addListener(() => notifications++);

    await controller.update(controller.settings);

    expect(notifications, 0);
  });

  test('patch 可以只改通知总开关', () async {
    await controller.patch(notificationsEnabled: false);
    expect(controller.settings.notificationsEnabled, isFalse);
    expect(controller.settings.defaultReminder, const ReminderSettings());
  });

  test('patch 支持自定义 transform', () async {
    await controller.patch(
      transform: (AppSettings current) =>
          current.copyWith(sortMode: ContactSortMode.recentlyUpdated),
    );
    expect(controller.settings.sortMode, ContactSortMode.recentlyUpdated);
  });

  test('patch 会先应用 transform 再覆盖 notificationsEnabled', () async {
    await controller.patch(
      notificationsEnabled: false,
      transform: (AppSettings current) =>
          current.copyWith(sortMode: ContactSortMode.name),
    );
    expect(controller.settings.sortMode, ContactSortMode.name);
    expect(controller.settings.notificationsEnabled, isFalse);
  });
}
