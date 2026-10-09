import 'package:birthday_keeper/app.dart';
import 'package:birthday_keeper/ui/pages/contact_edit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_harness.dart';

/// 整个 App 的端到端（Widget 层）冒烟测试。
void main() {
  Future<void> pumpApp(WidgetTester tester, TestHarness harness) async {
    await tester.pumpWidget(
      BirthdayKeeperApp(
        contactController: harness.contactController,
        settingsController: harness.settingsController,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  widgetTest('冷启动展示「即将到来」的引导页', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpApp(tester, harness);

    expect(find.text('生日管家'), findsOneWidget);
    expect(find.text('还没有联系人'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    // 三个标签都在
    expect(find.text('即将到来'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('联系人'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('设置'),
      ),
      findsOneWidget,
    );
  });

  widgetTest('底部导航可以切换页面', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpApp(tester, harness);

    NavigationBar bar() =>
        tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar().selectedIndex, 0);

    await tapTab(tester, '联系人');
    expect(bar().selectedIndex, 1);

    await tapTab(tester, '设置');
    expect(bar().selectedIndex, 2);

    await tapTab(tester, '即将到来');
    expect(bar().selectedIndex, 0);
  });

  widgetTest('完整流程：新建带生日的联系人 -> 出现在首页 -> 可以编辑', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpApp(tester, harness);

    // 1. 从空状态进入新建页面
    await tester.tap(find.text('添加第一位联系人'));
    await tester.pumpAndSettle();
    expect(find.byType(ContactEditPage), findsOneWidget);

    // 2. 填姓名 + 选择生日（日期选择器默认值：30 年前的 1 月 1 日）
    await tester.enterText(find.byKey(const Key('nameField')), '张三');
    await tester.tap(find.byKey(const Key('pickSolarDateButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    // 3. 保存
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    // 4. 回到首页并看到倒计时
    expect(find.byType(ContactEditPage), findsNothing);
    expect(harness.contactController.contacts, hasLength(1));
    expect(harness.contactRepository.saveCount, greaterThan(0));
    expect(find.text('张三'), findsOneWidget);
    expect(find.textContaining('天后'), findsWidgets);

    // 5. 提醒已经排好（2 次生日 × 提前 + 当天）
    expect(harness.scheduler.applied, hasLength(4));

    // 6. 进入详情再进编辑，改名字后首页同步更新
    await tester.tap(find.text('张三'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detailEditButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nameField')), '张三丰');
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    expect(harness.contactController.contacts.single.name, '张三丰');
  });

  widgetTest('设置里关闭提醒后首页仍可用', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpApp(tester, harness);

    await tapTab(tester, '设置');
    final Finder switchFinder = find.byKey(
      const Key('globalNotificationSwitch'),
    );
    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(harness.settingsController.settings.notificationsEnabled, isFalse);
    await tapTab(tester, '即将到来');
    expect(find.text('生日管家'), findsOneWidget);
  });
}
