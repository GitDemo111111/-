import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/models/relationship.dart';
import 'package:birthday_keeper/ui/pages/contact_detail_page.dart';
import 'package:birthday_keeper/ui/pages/contact_edit_page.dart';
import 'package:birthday_keeper/ui/pages/upcoming_page.dart';
import 'package:birthday_keeper/ui/widgets/contact_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  widgetTest('没有联系人时显示引导空状态', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();

    await tester.pumpWidget(harness.wrap(const UpcomingPage()));
    await tester.pumpAndSettle();

    expect(find.text('还没有联系人'), findsOneWidget);
    expect(find.text('添加第一位联系人'), findsOneWidget);
    expect(find.text('生日管家'), findsOneWidget);
    // 概览数字都是 0
    expect(find.text('今天生日'), findsOneWidget);
    expect(find.text('7 天内'), findsOneWidget);
  });

  widgetTest('有联系人时展示倒计时与关系', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(
          id: 'a',
          name: '张三',
          relationship: Relationship.friend,
          birthday: const Birthday(year: 1996, month: 5, day: 23),
        ),
      ],
    );
    await harness.load();

    await tester.pumpWidget(harness.wrap(const UpcomingPage()));
    await tester.pumpAndSettle();

    expect(find.text('张三'), findsOneWidget);
    expect(find.text('3天后'), findsOneWidget);
    expect(find.text('满30岁'), findsOneWidget);
    expect(find.text('朋友'), findsNothing);
    // 关系会拼接在日期后面，例如「5月23日 · 朋友」
    expect(find.textContaining('朋友'), findsOneWidget);
    // 「7 天内」既出现在顶部概览里，也作为分组标题出现
    expect(find.text('7 天内'), findsNWidgets(2));
    expect(find.text('共 1 位'), findsOneWidget);
  });

  widgetTest('今天生日会单独成组', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(
          id: 'a',
          name: '今天的人',
          birthday: const Birthday(month: 5, day: 20),
        ),
        makeContact(
          id: 'b',
          name: '以后的人',
          birthday: const Birthday(month: 8, day: 15),
        ),
      ],
    );
    await harness.load();

    await tester.pumpWidget(harness.wrap(const UpcomingPage()));
    await tester.pumpAndSettle();

    expect(find.text('今天生日'), findsWidgets);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('87天后'), findsOneWidget);
    expect(find.text('更远'), findsOneWidget);
  });

  widgetTest('没有生日的联系人不会出现在首页', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[makeContact(id: 'a', name: '无生日的人')],
    );
    await harness.load();

    await tester.pumpWidget(harness.wrap(const UpcomingPage()));
    await tester.pumpAndSettle();

    expect(find.text('无生日的人'), findsNothing);
    expect(find.text('还没有人生日'), findsOneWidget);
  });

  widgetTest('点击卡片进入详情页', (WidgetTester tester) async {
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

    await tester.pumpWidget(harness.wrap(const UpcomingPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(UpcomingTile));
    await tester.pumpAndSettle();

    expect(find.byType(ContactDetailPage), findsOneWidget);
  });

  widgetTest('点浮动按钮进入新建页面', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();

    await tester.pumpWidget(harness.wrap(const UpcomingPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactEditPage), findsOneWidget);
    expect(find.text('新建联系人'), findsOneWidget);
  });

  widgetTest('加载中显示进度指示器', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    // 故意不调用 load()，此时 isLoading 仍为 true。
    await tester.pumpWidget(harness.wrap(const UpcomingPage()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
