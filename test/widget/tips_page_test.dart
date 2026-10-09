import 'package:birthday_keeper/core/tips.dart';
import 'package:birthday_keeper/models/app_settings.dart';
import 'package:birthday_keeper/ui/pages/settings_page.dart';
import 'package:birthday_keeper/ui/pages/tips_page.dart';
import 'package:birthday_keeper/ui/pages/upcoming_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  Future<void> pumpTipsPage(WidgetTester tester, TestHarness harness) async {
    await tester.pumpWidget(harness.wrap(const TipsPage()));
    await tester.pumpAndSettle();
  }

  Future<void> pumpUpcomingPage(
    WidgetTester tester,
    TestHarness harness,
  ) async {
    await tester.pumpWidget(harness.wrap(const UpcomingPage()));
    await tester.pumpAndSettle();
  }

  Future<void> pumpSettingsPage(
    WidgetTester tester,
    TestHarness harness,
  ) async {
    await tester.pumpWidget(harness.wrap(const SettingsPage()));
    await tester.pumpAndSettle();
  }

  /// 先滚动到目标位置再点击，避免长页面里点不到屏外的组件。
  Future<void> tapKey(WidgetTester tester, Key key) async {
    final Finder finder = find.byKey(key);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  widgetTest('使用提示页列出全部提示', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpTipsPage(tester, harness);

    expect(find.text('使用提示'), findsOneWidget);
    expect(find.byKey(const Key('showTipCardSwitch')), findsOneWidget);
    for (final AppTip tip in kAppTips) {
      expect(find.byKey(Key('tipCard-${tip.id}')), findsOneWidget);
      expect(find.text(tip.title), findsOneWidget);
      expect(find.text(tip.body), findsOneWidget);
      expect(find.byKey(Key('hideTip-${tip.id}')), findsOneWidget);
    }
    // 一条都没隐藏时，不需要「恢复全部提示」。
    expect(find.byKey(const Key('restoreAllTipsButton')), findsNothing);
  });

  widgetTest('「不再提示」会写入设置并变成「恢复」', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpTipsPage(tester, harness);

    final String id = kAppTips.first.id;
    await tapKey(tester, Key('hideTip-$id'));

    expect(harness.settingsController.settings.hiddenTipIds, contains(id));
    expect(harness.settingsController.settings.isTipHidden(id), isTrue);
    expect(find.byKey(Key('hideTip-$id')), findsNothing);
    expect(find.byKey(Key('restoreTip-$id')), findsOneWidget);
    expect(find.text('已隐藏'), findsOneWidget);
    expect(find.byKey(const Key('restoreAllTipsButton')), findsOneWidget);

    // 单条恢复：只把这一条放出来。
    await tapKey(tester, Key('restoreTip-$id'));
    expect(harness.settingsController.settings.hiddenTipIds, isEmpty);
    expect(find.byKey(Key('hideTip-$id')), findsOneWidget);
    expect(find.byKey(const Key('restoreAllTipsButton')), findsNothing);
  });

  widgetTest('「恢复全部提示」会清空隐藏记录', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      settings: const AppSettings(
        hiddenTipIds: <String>['backup', 'lunar_calendar'],
      ),
    );
    await harness.load();
    await pumpTipsPage(tester, harness);

    expect(find.byKey(const Key('restoreTip-backup')), findsOneWidget);
    expect(find.byKey(const Key('restoreTip-lunar_calendar')), findsOneWidget);
    expect(find.textContaining('已隐藏 2 条'), findsOneWidget);

    await tapKey(tester, const Key('restoreAllTipsButton'));

    expect(harness.settingsController.settings.hiddenTipIds, isEmpty);
    expect(find.byKey(const Key('restoreAllTipsButton')), findsNothing);
    expect(find.byKey(const Key('hideTip-backup')), findsOneWidget);
    expect(find.byKey(const Key('hideTip-lunar_calendar')), findsOneWidget);
  });

  widgetTest('可以关掉首页的提示卡片', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpTipsPage(tester, harness);

    expect(harness.settingsController.settings.showTipCard, isTrue);
    await tapKey(tester, const Key('showTipCardSwitch'));

    expect(harness.settingsController.settings.showTipCard, isFalse);
  });

  widgetTest('首页显示当天的提示卡片，点小叉后换成下一条', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpUpcomingPage(tester, harness);

    final AppTip today = tipForDate(harness.now);
    expect(find.byKey(const Key('homeTipCard')), findsOneWidget);
    expect(find.text('使用提示 · ${today.title}'), findsOneWidget);
    expect(find.byKey(const Key('dismissTipButton')), findsOneWidget);

    await tapKey(tester, const Key('dismissTipButton'));

    expect(
      harness.settingsController.settings.hiddenTipIds,
      contains(today.id),
    );
    final AppTip next = kAppTips.firstWhere(
      (AppTip tip) => !harness.settingsController.settings.isTipHidden(tip.id),
    );
    // 当天那条被隐藏后，卡片换成第一条还没被隐藏的提示。
    expect(find.byKey(const Key('homeTipCard')), findsOneWidget);
    expect(find.text('使用提示 · ${next.title}'), findsOneWidget);

    // 所有提示都隐藏后，卡片彻底消失。
    for (final AppTip tip in kAppTips) {
      await harness.settingsController.hideTip(tip.id);
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('homeTipCard')), findsNothing);
  });

  widgetTest('关掉开关后首页不显示提示卡片', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      settings: const AppSettings(showTipCard: false),
    );
    await harness.load();
    await pumpUpcomingPage(tester, harness);

    expect(find.byKey(const Key('homeTipCard')), findsNothing);
    expect(find.byKey(const Key('dismissTipButton')), findsNothing);
  });

  widgetTest('点击首页提示卡片进入使用提示页', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpUpcomingPage(tester, harness);

    await tapKey(tester, const Key('homeTipCard'));

    expect(find.byType(TipsPage), findsOneWidget);
    expect(find.text('全部提示'), findsOneWidget);
  });

  widgetTest('设置里的「使用提示」入口打开提示页', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      settings: const AppSettings(hiddenTipIds: <String>['backup']),
    );
    await harness.load();
    await pumpSettingsPage(tester, harness);

    expect(find.text('使用提示'), findsOneWidget);
    expect(find.text('已隐藏 1 条'), findsOneWidget);

    await tapKey(tester, const Key('tipsEntry'));

    expect(find.byType(TipsPage), findsOneWidget);
    expect(find.byKey(const Key('showTipCardSwitch')), findsOneWidget);

    // 在提示页里恢复后，返回设置页时隐藏数量会同步更新。
    await tapKey(tester, const Key('restoreTip-backup'));
    expect(harness.settingsController.settings.hiddenTipIds, isEmpty);

    // 返回键在中文环境下没有英文 tooltip，pageBack() 找不到它，直接点 BackButton。
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('查看全部使用技巧'), findsOneWidget);
  });
}
