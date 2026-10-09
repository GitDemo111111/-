import 'dart:io';

import 'package:birthday_keeper/app.dart';
import 'package:birthday_keeper/data/json_contact_repository.dart';
import 'package:birthday_keeper/data/json_settings_repository.dart';
import 'package:birthday_keeper/data/json_store.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/services/reminder_scheduler.dart';
import 'package:birthday_keeper/state/contact_controller.dart';
import 'package:birthday_keeper/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/test_harness.dart';

/// 在真机 / 模拟器上跑的集成测试。
///
/// 除了走通界面流程，还额外验证真实文件系统上的持久化。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('真机上的主流程：新建联系人 -> 首页倒计时 -> 编辑', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();

    await tester.pumpWidget(
      BirthdayKeeperApp(
        contactController: harness.contactController,
        settingsController: harness.settingsController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有联系人'), findsOneWidget);

    await tester.tap(find.text('添加').first); // 右下角 FAB
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('nameField')), '集成测试联系人');
    await tester.tap(find.byKey(const Key('pickSolarDateButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    expect(find.text('集成测试联系人'), findsWidgets);
    expect(harness.scheduler.applied, isNotEmpty);
  });

  testWidgets('真实依赖可以读回刚写入的联系人', (WidgetTester tester) async {
    final Directory dir = await getApplicationSupportDirectory();
    final Directory dataDir = Directory('${dir.path}/integration_test_data');
    if (dataDir.existsSync()) {
      await dataDir.delete(recursive: true);
    }

    JsonStore storeFor(String name) =>
        JsonStore(resolveFile: () async => File('${dataDir.path}/$name'));

    final SettingsController settings = SettingsController(
      repository: JsonSettingsRepository(store: storeFor('settings.json')),
    );
    await settings.load();

    final ContactController first = ContactController(
      repository: JsonContactRepository(store: storeFor('contacts.json')),
      settings: settings,
      scheduler: NoopReminderScheduler(),
    );
    await first.load();
    expect(first.contacts, isEmpty);

    final DateTime now = DateTime.now();
    await first.addContact(
      Contact(
        id: 'device-1',
        name: '真机联系人',
        birthday: const Birthday(month: 8, day: 15),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 用一套全新的依赖重新读取，确认真的落到了磁盘上。
    final SettingsController settingsAgain = SettingsController(
      repository: JsonSettingsRepository(store: storeFor('settings.json')),
    );
    await settingsAgain.load();
    final ContactController second = ContactController(
      repository: JsonContactRepository(store: storeFor('contacts.json')),
      settings: settingsAgain,
      scheduler: NoopReminderScheduler(),
    );
    await second.load();

    expect(second.contacts, hasLength(1));
    expect(second.contacts.single.name, '真机联系人');
    expect(second.contacts.single.birthday, const Birthday(month: 8, day: 15));

    if (dataDir.existsSync()) {
      await dataDir.delete(recursive: true);
    }
  });

  testWidgets('真机上的农历换算可用', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(
          id: 'lunar',
          name: '农历生日',
          birthday: const Birthday(
            month: 8,
            day: 15,
            calendar: BirthdayCalendar.lunar,
          ),
        ),
      ],
    );
    await harness.load();

    await tester.pumpWidget(
      BirthdayKeeperApp(
        contactController: harness.contactController,
        settingsController: harness.settingsController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('农历生日'), findsOneWidget);
    expect(harness.contactController.upcoming, hasLength(1));
  });

  testWidgets('主题与中文本地化已生效', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();

    await tester.pumpWidget(
      BirthdayKeeperApp(
        contactController: harness.contactController,
        settingsController: harness.settingsController,
      ),
    );
    await tester.pumpAndSettle();

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.locale, const Locale('zh', 'CN'));
    expect(app.theme?.useMaterial3, isTrue);
  });
}
