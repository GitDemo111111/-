import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_dependencies.dart';
import 'data/json_contact_repository.dart';
import 'data/json_settings_repository.dart';
import 'data/json_store.dart';
import 'services/local_notification_scheduler.dart';
import 'services/reminder_scheduler.dart';
import 'state/contact_controller.dart';
import 'state/settings_controller.dart';

/// 手机 / 桌面端：JSON 文件持久化 + 系统本地通知。
Future<AppDependencies> createAppDependencies() async {
  final Directory supportDir = await getApplicationSupportDirectory();
  final Directory dataDir = Directory('${supportDir.path}/data');

  final JsonStore contactsStore = JsonStore(
    resolveFile: () async => File('${dataDir.path}/contacts.json'),
  );
  final JsonStore settingsStore = JsonStore(
    resolveFile: () async => File('${dataDir.path}/settings.json'),
  );

  final ReminderScheduler scheduler = LocalNotificationScheduler();
  final SettingsController settingsController = SettingsController(
    repository: JsonSettingsRepository(store: settingsStore),
  );
  final ContactController contactController = ContactController(
    repository: JsonContactRepository(store: contactsStore),
    settings: settingsController,
    scheduler: scheduler,
  );

  return AppDependencies(
    settingsController: settingsController,
    contactController: contactController,
    scheduler: scheduler,
  );
}
