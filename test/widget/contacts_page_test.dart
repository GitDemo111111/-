import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/models/relationship.dart';
import 'package:birthday_keeper/ui/pages/contact_detail_page.dart';
import 'package:birthday_keeper/ui/pages/contacts_page.dart';
import 'package:birthday_keeper/ui/widgets/contact_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  Future<void> pumpContacts(WidgetTester tester, TestHarness harness) async {
    await tester.pumpWidget(harness.wrap(const ContactsPage()));
    await tester.pumpAndSettle();
  }

  widgetTest('没有联系人时显示空状态', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpContacts(tester, harness);

    expect(find.text('还没有联系人'), findsOneWidget);
    expect(find.text('添加联系人'), findsOneWidget);
  });

  widgetTest('列出全部联系人并显示生日与年龄', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(
          id: 'a',
          name: '张三',
          relationship: Relationship.friend,
          birthday: const Birthday(year: 1996, month: 5, day: 23),
          hobbies: <String>['咖啡'],
        ),
        makeContact(id: 'b', name: '李四'),
      ],
    );
    await harness.load();
    await pumpContacts(tester, harness);

    expect(find.byType(ContactTile), findsNWidgets(2));
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('李四'), findsOneWidget);
    expect(find.text('3天后'), findsOneWidget);
    expect(find.text('满30岁'), findsOneWidget);
    expect(find.text('共 2 位'), findsOneWidget);
    // 没有生日的人显示提示文案
    expect(find.text('还没有填写生日'), findsOneWidget);
  });

  widgetTest('搜索可以过滤列表', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(id: 'a', name: '张三'),
        makeContact(id: 'b', name: '李四'),
        makeContact(id: 'c', name: '王五'),
      ],
    );
    await harness.load();
    await pumpContacts(tester, harness);

    await tester.enterText(find.byKey(const Key('searchField')), '李');
    await tester.pumpAndSettle();

    expect(find.byType(ContactTile), findsOneWidget);
    expect(find.text('李四'), findsOneWidget);
    expect(find.text('张三'), findsNothing);
    expect(find.text('共 1 位'), findsOneWidget);
  });

  widgetTest('搜索不到时提示清除筛选', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[makeContact(id: 'a', name: '张三')],
    );
    await harness.load();
    await pumpContacts(tester, harness);

    await tester.enterText(find.byKey(const Key('searchField')), '不存在');
    await tester.pumpAndSettle();

    expect(find.text('没有符合条件的联系人'), findsOneWidget);
    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();
    expect(find.byType(ContactTile), findsOneWidget);
  });

  widgetTest('可以按关系筛选', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(id: 'a', name: '同事甲', relationship: Relationship.colleague),
        makeContact(id: 'b', name: '朋友乙', relationship: Relationship.friend),
      ],
    );
    await harness.load();
    await pumpContacts(tester, harness);

    await tester.tap(find.byKey(const Key('relationFilter-同事')));
    await tester.pumpAndSettle();

    expect(find.byType(ContactTile), findsOneWidget);
    expect(find.text('同事甲'), findsOneWidget);
  });

  widgetTest('可以只看星标联系人', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(id: 'a', name: '普通人'),
        makeContact(id: 'b', name: '星标用户', favorite: true),
      ],
    );
    await harness.load();
    await pumpContacts(tester, harness);

    await tester.tap(find.byKey(const Key('favoriteFilterChip')));
    await tester.pumpAndSettle();

    expect(find.byType(ContactTile), findsOneWidget);
    expect(find.text('星标用户'), findsOneWidget);
    expect(find.text('普通人'), findsNothing);
  });

  widgetTest('可以打开爱好筛选面板并按爱好过滤', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(id: 'a', name: '爱咖啡', hobbies: <String>['咖啡']),
        makeContact(id: 'b', name: '爱徒步', hobbies: <String>['徒步']),
      ],
    );
    await harness.load();
    await pumpContacts(tester, harness);

    await tester.tap(find.byKey(const Key('hobbyFilterButton')));
    await tester.pumpAndSettle();
    expect(find.text('按爱好筛选'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hobbyFilter-咖啡')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactTile), findsOneWidget);
    expect(find.text('爱咖啡'), findsOneWidget);
  });

  widgetTest('点击联系人进入详情页', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[makeContact(id: 'a', name: '张三')],
    );
    await harness.load();
    await pumpContacts(tester, harness);

    await tester.tap(find.byType(ContactTile));
    await tester.pumpAndSettle();

    expect(find.byType(ContactDetailPage), findsOneWidget);
  });

  widgetTest('点浮动按钮进入新建页面', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpContacts(tester, harness);

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.text('新建联系人'), findsOneWidget);
  });
}
