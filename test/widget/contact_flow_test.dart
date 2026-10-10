import 'package:birthday_keeper/models/app_settings.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/models/relationship.dart';
import 'package:birthday_keeper/state/root_tab_controller.dart';
import 'package:birthday_keeper/ui/pages/contact_edit_page.dart';
import 'package:birthday_keeper/ui/pages/contact_import_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

/// 这几条覆盖本轮需求里跨度较大的行为：
/// 保存后回联系人页、两级关系选择、批量导入交接、重复自动合并、默认历法开关。
void main() {
  Future<void> pumpEditor(
    WidgetTester tester,
    TestHarness harness, {
    String? contactId,
  }) async {
    await tester.pumpWidget(
      harness.wrap(ContactEditPage(contactId: contactId)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpImport(
    WidgetTester tester,
    TestHarness harness, {
    String initialText = '',
  }) async {
    await tester.pumpWidget(
      harness.wrap(ContactImportPage(initialText: initialText)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> paste(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('importTextField')), text);
    await tester.pumpAndSettle();
  }

  group('保存后回到联系人页', () {
    widgetTest('新建联系人也一样', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpEditor(tester, harness);

      expect(harness.rootTabController.index, RootTabController.upcomingTab);

      await tester.enterText(find.byKey(const Key('nameField')), '张三');
      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      expect(harness.contactController.contacts, hasLength(1));
      // 自动切到「联系人」页
      expect(harness.rootTabController.index, RootTabController.contactsTab);
    });

    widgetTest('编辑已有联系人同样会切过去', (WidgetTester tester) async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[makeContact(id: 'a', name: '张三')],
      );
      await harness.load();
      await pumpEditor(tester, harness, contactId: 'a');

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      expect(harness.rootTabController.index, RootTabController.contactsTab);
    });
  });

  group('两级关系选择器：家人里就有爸爸/妈妈', () {
    widgetTest('家人分组展开后能直接选爸爸', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpEditor(tester, harness);

      // 默认展开「家人」
      expect(find.byKey(const Key('relationChip-father')), findsOneWidget);
      expect(find.byKey(const Key('relationChip-mother')), findsOneWidget);
      expect(find.byKey(const Key('relationChip-grandpa')), findsOneWidget);

      await tester.tap(find.byKey(const Key('relationChip-father')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('nameField')), '爸爸');
      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      final Contact saved = harness.contactController.contacts.single;
      expect(saved.relationship, Relationship.father);
      expect(saved.relationship!.group, RelationshipGroup.family);
      expect(saved.relationshipLabel, '爸爸');
    });

    widgetTest('切到别的分组会换成那个分组的角色', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpEditor(tester, harness);

      await tester.tap(find.byKey(const Key('relationGroup-colleague')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('relationChip-colleague')), findsOneWidget);
      expect(find.byKey(const Key('relationChip-boss')), findsOneWidget);
      // 家人那一组已经不显示了
      expect(find.byKey(const Key('relationChip-father')), findsNothing);
    });

    widgetTest('已经选过的关系会展开对应分组', (WidgetTester tester) async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(id: 'a', name: '李总', relationship: Relationship.boss),
        ],
      );
      await harness.load();
      await pumpEditor(tester, harness, contactId: 'a');

      expect(find.byKey(const Key('relationChip-boss')), findsOneWidget);
      expect(find.text('已选：领导'), findsOneWidget);
    });
  });

  group('文本填充遇到多位联系人', () {
    widgetTest('提示只填第一位，并可一键转批量导入', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpEditor(tester, harness);

      await tester.tap(find.byKey(const Key('fillFromTextButton')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('fillTextField')),
        '姓名：张三\n生日：新历5月20日\n\n姓名：李四\n生日：新历6月1日',
      );
      await tester.pumpAndSettle();

      expect(find.text('识别到 2 位联系人'), findsOneWidget);
      expect(find.textContaining('只会填第一位'), findsOneWidget);
      expect(find.byKey(const Key('fillBatchImportButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('fillBatchImportButton')));
      await tester.pumpAndSettle();

      // 编辑页关掉，跳到批量导入页且文本已带过去
      expect(find.byType(ContactEditPage), findsNothing);
      expect(find.byType(ContactImportPage), findsOneWidget);
      expect(find.text('2 位可导入'), findsOneWidget);
      expect(find.text('张三'), findsOneWidget);
      expect(find.text('李四'), findsOneWidget);
    });

    widgetTest('只有一位时不会出现批量按钮', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpEditor(tester, harness);

      await tester.tap(find.byKey(const Key('fillFromTextButton')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('fillTextField')), '姓名：张三');
      await tester.pumpAndSettle();

      expect(find.text('识别到 1 位联系人'), findsOneWidget);
      expect(find.byKey(const Key('fillBatchImportButton')), findsNothing);
    });
  });

  group('重复联系人自动合并', () {
    widgetTest('同名且信息一致 -> 不重复添加', (WidgetTester tester) async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(
            id: 'a',
            name: '张三',
            birthday: const Birthday(month: 5, day: 20),
            hobbies: <String>['咖啡'],
          ),
        ],
      );
      await harness.load();
      await pumpImport(tester, harness);

      await paste(tester, '姓名：张三\n生日：新历5月20日\n爱好：咖啡');

      expect(find.text('重复，自动合并'), findsOneWidget);
      expect(find.textContaining('1 位重复将合并'), findsOneWidget);
      final FilledButton button = tester.widget<FilledButton>(
        find.byKey(const Key('doImportButton')),
      );
      expect(button.onPressed, isNull);
      expect(harness.contactController.contacts, hasLength(1));
    });

    widgetTest('同名但信息不同 -> 仍然新增并提示', (WidgetTester tester) async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[makeContact(id: 'a', name: '张三')],
      );
      await harness.load();
      await pumpImport(tester, harness);

      await paste(tester, '姓名：张三\n生日：新历5月20日');

      expect(find.text('已有同名，将新增'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('doImportButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('doImportButton')));
      await tester.pumpAndSettle();

      expect(harness.contactController.contacts, hasLength(2));
    });

    widgetTest('混合场景：一位合并、一位新增', (WidgetTester tester) async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[makeContact(id: 'a', name: '张三')],
      );
      await harness.load();
      await pumpImport(tester, harness);

      await paste(tester, '姓名：张三\n\n姓名：李四\n生日：新历6月1日');

      expect(find.text('重复，自动合并'), findsOneWidget);
      expect(find.text('2 位可导入，1 位重复将合并'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('doImportButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('doImportButton')));
      await tester.pumpAndSettle();

      expect(harness.contactController.contacts, hasLength(2));
      expect(
        harness.contactController.contacts.map((Contact c) => c.name),
        containsAll(<String>['张三', '李四']),
      );
    });
  });

  group('默认历法开关', () {
    widgetTest('默认新历：没写历法按新历解析', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpImport(tester, harness);

      // 设置里的默认值是新历（用户真实数据里农历都会显式标注）
      expect(
        harness.settingsController.settings.importCalendar,
        BirthdayCalendar.solar,
      );

      await paste(tester, '姓名：张三\n生日：5月20日');
      expect(find.text('5月20日'), findsWidgets);
    });

    widgetTest('切到农历后立即重新解析并记住设置', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpImport(tester, harness);

      await paste(tester, '姓名：张三\n生日：5月20日');
      expect(find.text('农历5月20日'), findsNothing);

      await tester.tap(find.byKey(const Key('importCalendar-lunar')));
      await tester.pumpAndSettle();

      expect(find.text('农历5月20日'), findsWidgets);
      expect(
        harness.settingsController.settings.importCalendar,
        BirthdayCalendar.lunar,
      );
      // 设置写回了仓库
      expect(
        (await harness.settingsRepository.load()).importCalendar,
        BirthdayCalendar.lunar,
      );
    });

    widgetTest('文本里写了农历就以文本为准', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpImport(tester, harness);

      await paste(tester, '姓名：张三\n生日：农历八月十五');
      expect(find.text('农历8月15日'), findsWidgets);
    });
  });
}
