import 'package:birthday_keeper/models/app_settings.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/services/backup_service.dart';
import 'package:birthday_keeper/ui/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  Future<void> pumpSettings(WidgetTester tester, TestHarness harness) async {
    await tester.pumpWidget(harness.wrap(const SettingsPage()));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  widgetTest('展示默认提醒设置与统计', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(id: 'a', birthday: const Birthday(month: 8, day: 15)),
        makeContact(id: 'b'),
      ],
    );
    await harness.load();
    await pumpSettings(tester, harness);

    expect(find.text('设置'), findsWidgets);
    expect(find.text('开启生日提醒'), findsOneWidget);
    expect(find.text('共 2 位联系人，1 位有生日'), findsOneWidget);
    // 两位联系人里只有一位有生日 -> 2 次生日 × 2 种提醒
    expect(find.text('已为 4 次生日排好提醒'), findsOneWidget);
  });

  widgetTest('关闭总开关会更新设置并取消提醒', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(id: 'a', birthday: const Birthday(month: 8, day: 15)),
      ],
    );
    await harness.load();
    await pumpSettings(tester, harness);

    await tapVisible(tester, find.byKey(const Key('globalNotificationSwitch')));

    expect(harness.settingsController.settings.notificationsEnabled, isFalse);
    expect(harness.scheduler.applied, isEmpty);
    expect(find.text('提醒已关闭'), findsOneWidget);
  });

  widgetTest('可以切换排序方式', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpSettings(tester, harness);

    await tapVisible(tester, find.byKey(const Key('sortMode-name')));

    expect(harness.settingsController.settings.sortMode, ContactSortMode.name);
  });

  widgetTest('可以关闭农历显示与分组', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpSettings(tester, harness);

    await tapVisible(tester, find.byKey(const Key('showLunarSwitch')));
    expect(harness.settingsController.settings.showLunarInfo, isFalse);

    await tapVisible(tester, find.byKey(const Key('groupUpcomingSwitch')));
    expect(harness.settingsController.settings.groupUpcoming, isFalse);
  });

  widgetTest('调整默认提前天数', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpSettings(tester, harness);

    final Finder slider = find.byKey(const Key('defaultDaysBeforeSlider'));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    await tester.drag(slider, const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(
      harness.settingsController.settings.defaultReminder.daysBefore,
      greaterThan(3),
    );
  });

  widgetTest('导出备份会展示可复制的 JSON', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(
          id: 'a',
          name: '张三',
          birthday: const Birthday(month: 8, day: 15),
        ),
      ],
    );
    await harness.load();
    installClipboardMock(tester);
    await pumpSettings(tester, harness);

    await tapVisible(tester, find.byKey(const Key('exportButton')));

    expect(find.byType(AlertDialog), findsOneWidget);
    // 对话框里是完整备份内容
    expect(find.textContaining('birthdayKeeper'), findsOneWidget);
    expect(find.textContaining('张三'), findsWidgets);

    await tapVisible(tester, find.byKey(const Key('copyBackupButton')));
    expect(find.text('备份内容已复制到剪贴板'), findsOneWidget);
  });

  widgetTest('导入对话框能解析合法备份', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpSettings(tester, harness);

    final String json = const BackupService().exportToJson(
      contacts: <Contact>[makeContact(id: 'x', name: '导入的人')],
      settings: const AppSettings(),
      now: kNow,
    );

    await tapVisible(tester, find.byKey(const Key('importButton')));
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(find.byKey(const Key('importTextField')), json);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('parseBackupButton')));

    expect(find.textContaining('解析成功：1 位联系人'), findsOneWidget);

    await tapVisible(tester, find.byKey(const Key('mergeImportButton')));

    expect(harness.contactController.contacts, hasLength(1));
    expect(harness.contactController.contacts.single.name, '导入的人');
    expect(find.textContaining('已合并导入 1 位联系人'), findsOneWidget);
  });

  widgetTest('导入非法内容会给出错误提示', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpSettings(tester, harness);

    await tapVisible(tester, find.byKey(const Key('importButton')));
    await tester.enterText(find.byKey(const Key('importTextField')), '这不是备份');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('parseBackupButton')));

    expect(find.textContaining('合法的 JSON'), findsOneWidget);
    // 仍然停留在对话框
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  widgetTest('清空所有联系人需要确认', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[makeContact(id: 'a', name: '张三')],
    );
    await harness.load();
    await pumpSettings(tester, harness);

    await tapVisible(tester, find.byKey(const Key('clearAllButton')));
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '清空'));
    await tester.pumpAndSettle();

    expect(harness.contactController.contacts, isEmpty);
    expect(find.text('已清空所有联系人'), findsOneWidget);
  });

  widgetTest('没有联系人时清空按钮不可用', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpSettings(tester, harness);

    final Finder button = find.byKey(const Key('clearAllButton'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(button).onPressed, isNull);
  });

  widgetTest('展示版本号与说明', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpSettings(tester, harness);

    expect(find.text('生日管家 v$kAppVersion'), findsOneWidget);
    expect(find.textContaining('数据全部保存在手机本地'), findsOneWidget);
  });
}
