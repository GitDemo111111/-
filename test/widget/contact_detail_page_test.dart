import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/models/relationship.dart';
import 'package:birthday_keeper/ui/pages/contact_detail_page.dart';
import 'package:birthday_keeper/ui/pages/contact_edit_page.dart';
import 'package:birthday_keeper/ui/pages/upcoming_page.dart';
import 'package:birthday_keeper/ui/widgets/contact_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  Future<void> pumpDetail(
    WidgetTester tester,
    TestHarness harness,
    String id,
  ) async {
    await tester.pumpWidget(harness.wrap(ContactDetailPage(contactId: id)));
    await tester.pumpAndSettle();
  }

  widgetTest('联系人不存在时显示兜底页面', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpDetail(tester, harness, 'nope');

    expect(find.text('联系人不存在'), findsOneWidget);
  });

  widgetTest('展示姓名、关系、倒计时、年龄、星座与生肖', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(
          id: 'a',
          name: '张三',
          relationship: Relationship.friend,
          relationLabel: '大学室友',
          birthday: const Birthday(year: 1996, month: 5, day: 23),
        ),
      ],
    );
    await harness.load();
    await pumpDetail(tester, harness, 'a');

    expect(find.text('张三'), findsWidgets);
    expect(find.text('朋友 · 大学室友'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // 倒计时天数
    expect(find.text('天后生日'), findsOneWidget);
    expect(find.text('将满 30 岁'), findsOneWidget);
    expect(find.text('2026年5月23日 周六'), findsOneWidget);
    expect(find.text('双子座'), findsOneWidget);
    expect(find.text('属鼠'), findsOneWidget);
    // 公历生日也会显示对应的农历日期
    expect(find.textContaining('农历'), findsWidgets);
  });

  widgetTest('今天生日时显示庆祝文案', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(
          id: 'a',
          name: '寿星',
          birthday: const Birthday(month: 5, day: 20),
        ),
      ],
    );
    await harness.load();
    await pumpDetail(tester, harness, 'a');

    expect(find.text('🎉 今天生日'), findsOneWidget);
    expect(find.textContaining('记得送上生日祝福'), findsOneWidget);
  });

  widgetTest('没有生日时提示去补上', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[makeContact(id: 'a', name: '无生日')],
    );
    await harness.load();
    await pumpDetail(tester, harness, 'a');

    expect(find.textContaining('还没有记录生日'), findsOneWidget);
    expect(find.text('还没有生日，无法提醒'), findsOneWidget);
  });

  widgetTest('展示提醒设置摘要', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(
          id: 'a',
          name: '张三',
          birthday: const Birthday(month: 8, day: 15),
          reminder: const ReminderSettings(daysBefore: 5, hour: 18, minute: 30),
        ),
      ],
    );
    await harness.load();
    await pumpDetail(tester, harness, 'a');

    expect(find.text('提前5天 + 当天 18:30'), findsOneWidget);
  });

  widgetTest('展示联系方式、爱好、礼物灵感、备注和标签', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(
          id: 'a',
          name: '张三',
          phone: '13800000000',
          wechat: 'zhangsan_wx',
          email: 'zhangsan@example.com',
          hobbies: <String>['咖啡', '徒步'],
          giftIdeas: '喜欢机械键盘',
          notes: '对花生过敏',
          tags: <String>['重要'],
        ),
      ],
    );
    await harness.load();
    await pumpDetail(tester, harness, 'a');

    expect(find.text('13800000000'), findsOneWidget);
    expect(find.text('zhangsan_wx'), findsOneWidget);
    expect(find.text('zhangsan@example.com'), findsOneWidget);
    expect(find.text('爱好'), findsOneWidget);
    expect(find.text('咖啡'), findsOneWidget);
    expect(find.text('徒步'), findsOneWidget);
    expect(find.text('礼物灵感'), findsOneWidget);
    expect(find.text('喜欢机械键盘'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);
    expect(find.text('对花生过敏'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('重要'), findsOneWidget);
  });

  widgetTest('点击手机号会复制到剪贴板', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(id: 'a', name: '张三', phone: '13800000000'),
      ],
    );
    await harness.load();
    final List<MethodCall> clipboardCalls = installClipboardMock(tester);
    await pumpDetail(tester, harness, 'a');

    await tester.tap(find.text('13800000000'));
    await tester.pumpAndSettle();

    expect(find.text('已复制手机号'), findsOneWidget);
    // 确认真的把号码写进了系统剪贴板
    final MethodCall call = clipboardCalls.firstWhere(
      (MethodCall c) => c.method == 'Clipboard.setData',
    );
    expect((call.arguments as Map<Object?, Object?>)['text'], '13800000000');
  });

  widgetTest('可以切换星标', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[makeContact(id: 'a', name: '张三')],
    );
    await harness.load();
    await pumpDetail(tester, harness, 'a');

    expect(harness.contactController.contactById('a')!.favorite, isFalse);

    await tester.tap(find.byKey(const Key('detailFavoriteButton')));
    await tester.pumpAndSettle();

    expect(harness.contactController.contactById('a')!.favorite, isTrue);
  });

  widgetTest('点编辑按钮进入编辑页', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[makeContact(id: 'a', name: '张三')],
    );
    await harness.load();
    await pumpDetail(tester, harness, 'a');

    await tester.tap(find.byKey(const Key('detailEditButton')));
    await tester.pumpAndSettle();

    expect(find.byType(ContactEditPage), findsOneWidget);
    expect(find.text('编辑联系人'), findsOneWidget);
  });

  widgetTest('删除需要二次确认，确认后移除并返回上一页', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(
          id: 'a',
          name: '张三',
          birthday: const Birthday(month: 8, day: 15),
        ),
        makeContact(
          id: 'b',
          name: '李四',
          birthday: const Birthday(month: 9, day: 20),
        ),
      ],
    );
    await harness.load();

    // 从首页进入详情，这样删除后才有页面可以返回。
    await tester.pumpWidget(harness.wrap(const UpcomingPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(UpcomingTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(ContactDetailPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('detailDeleteButton')));
    await tester.pumpAndSettle();
    expect(find.text('删除联系人'), findsOneWidget);

    // 先取消，联系人应该还在
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(harness.contactController.contacts, hasLength(2));
    expect(find.byType(ContactDetailPage), findsOneWidget);

    // 再确认删除
    await tester.tap(find.byKey(const Key('detailDeleteButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(
      harness.contactController.contacts.map((Contact c) => c.id),
      <String>['b'],
    );
    // 已经回到列表页
    expect(find.byType(ContactDetailPage), findsNothing);
    expect(find.byType(UpcomingPage), findsOneWidget);
  });
}
