import 'package:birthday_keeper/core/contact_text_parser.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/models/relationship.dart';
import 'package:birthday_keeper/ui/pages/contact_import_page.dart';
import 'package:birthday_keeper/ui/widgets/contact_text_help.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  Future<void> pumpImport(WidgetTester tester, TestHarness harness) async {
    await tester.pumpWidget(harness.wrap(const ContactImportPage()));
    await tester.pumpAndSettle();
  }

  Future<void> paste(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('importTextField')), text);
    await tester.pumpAndSettle();
  }

  group('格式说明', () {
    widgetTest('页面一开始就明确展示格式与示例', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpImport(tester, harness);

      // 顶部常驻的简短说明
      expect(find.textContaining('一行一个字段'), findsOneWidget);
      expect(find.textContaining('其它行不写就不填'), findsOneWidget);
      expect(find.textContaining('农历八月十五'), findsOneWidget);
      // 完整说明（含示例）一键可达
      expect(find.byKey(const Key('useExampleButton')), findsOneWidget);
      expect(find.byKey(const Key('inlineHelpButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('inlineHelpButton')));
      await tester.pumpAndSettle();
      expect(find.text('支持的文本格式'), findsOneWidget);
      expect(find.text('支持的格式'), findsOneWidget);
      expect(find.text('示例（可直接复制修改）'), findsOneWidget);
      expect(find.textContaining('姓名：张三'), findsWidgets);

      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
    });

    widgetTest('AppBar 的说明按钮也能打开完整格式', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpImport(tester, harness);

      await tester.tap(find.byKey(const Key('showFormatHelpButton')));
      await tester.pumpAndSettle();
      expect(find.text('支持的文本格式'), findsOneWidget);
    });

    widgetTest('点「填入示例」会把示例填进输入框并解析出来', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpImport(tester, harness);

      await tester.tap(find.byKey(const Key('useExampleButton')));
      await tester.pumpAndSettle();

      expect(find.text('识别结果'), findsOneWidget);
      expect(find.text('张三'), findsOneWidget);
      // 星座 / 生肖是自动识别出来的
      expect(find.text('星座'), findsOneWidget);
      expect(find.text('金牛座'), findsOneWidget);
      expect(find.text('生肖'), findsOneWidget);
      expect(find.text('属猪'), findsOneWidget);
    });
  });

  group('解析预览', () {
    widgetTest('粘贴后展示解析到的字段与自动识别的星座', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpImport(tester, harness);

      await paste(
        tester,
        '姓名：李四\n关系：同事\n生日：新历1993-05-20\n手机：13900000000\n爱好：咖啡、徒步',
      );

      expect(find.text('李四'), findsOneWidget);
      expect(find.text('同事'), findsOneWidget);
      expect(find.text('1993年5月20日'), findsOneWidget);
      expect(find.text('13900000000'), findsOneWidget);
      expect(find.text('咖啡、徒步'), findsOneWidget);
      // 生日 -> 自动识别星座（5/20 是金牛座）
      expect(find.text('金牛座'), findsOneWidget);
      expect(find.text('自动识别'), findsNothing); // 这是编辑页的标题
    });

    widgetTest('一次粘贴多位会全部列出来', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpImport(tester, harness);

      await paste(tester, '姓名：张三\n生日：新历5月20日\n\n姓名：李四\n生日：新历6月1日');

      expect(find.text('2 位可导入'), findsOneWidget);
      expect(find.byKey(const Key('importPreview-0')), findsOneWidget);
      expect(find.byKey(const Key('importPreview-1')), findsOneWidget);
      expect(find.text('金牛座'), findsWidgets);
      expect(find.text('双子座'), findsWidgets);
    });

    widgetTest('缺姓名的条目会标出来且不能导入', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpImport(tester, harness);

      await paste(tester, '生日：5月20日');

      expect(find.text('缺少姓名，无法导入'), findsOneWidget);
      expect(find.textContaining('1 条有问题'), findsOneWidget);
      final FilledButton button = tester.widget<FilledButton>(
        find.byKey(const Key('doImportButton')),
      );
      expect(button.onPressed, isNull);
    });

    widgetTest('认不出的字段会提示并放进备注', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpImport(tester, harness);

      await paste(tester, '姓名：张三\n血型：O型');

      expect(find.textContaining('不是内置字段'), findsOneWidget);
      expect(find.text('血型：O型'), findsOneWidget);
    });

    widgetTest('与已有联系人同名会提示', (WidgetTester tester) async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[makeContact(id: 'a', name: '张三')],
      );
      await harness.load();
      await pumpImport(tester, harness);

      await paste(tester, '姓名：张三\n生日：新历5月20日');
      expect(find.text('已有同名，将新增'), findsOneWidget);
    });

    widgetTest('清空按钮会重置输入', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpImport(tester, harness);

      await paste(tester, '姓名：张三');
      expect(find.byKey(const Key('clearImportTextButton')), findsOneWidget);

      await tester.tap(find.byKey(const Key('clearImportTextButton')));
      await tester.pumpAndSettle();

      expect(find.text('还没有可导入的内容'), findsOneWidget);
      expect(harness.contactController.contacts, isEmpty);
    });
  });

  group('导入', () {
    widgetTest('单条导入会写入控制器并落盘', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpImport(tester, harness);

      await paste(tester, kContactTextExample);
      await tapImportButton(tester);

      expect(harness.contactController.contacts, hasLength(1));
      final Contact saved = harness.contactController.contacts.single;
      expect(saved.name, '张三');
      expect(saved.relationship, Relationship.friend);
      expect(saved.relationLabel, '大学室友');
      expect(saved.birthday, const Birthday(year: 1995, month: 5, day: 20));
      expect(saved.hobbies, <String>['咖啡', '徒步']);
      expect(saved.phone, '13800000000');
      expect(saved.notes, '对花生过敏');
      expect(saved.avatarEmoji, '😀');
      // 提醒用的是设置里的默认值
      expect(saved.reminder.daysBefore, 3);
      expect(harness.contactRepository.saveCount, greaterThan(0));
      // 导入完自动返回
      expect(find.byType(ContactImportPage), findsNothing);
    });

    widgetTest('批量导入多位的数量正确', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpImport(tester, harness);

      await paste(tester, '姓名：张三\n生日：新历5月20日\n\n姓名：李四\n生日：农历八月十五\n\n姓名：王五');
      expect(find.text('3 位可导入'), findsOneWidget);

      await tapImportButton(tester);

      expect(harness.contactController.contacts, hasLength(3));
      final Contact lunar = harness.contactController.contacts.firstWhere(
        (Contact c) => c.name == '李四',
      );
      expect(lunar.birthday!.calendar, BirthdayCalendar.lunar);
      expect(lunar.birthday!.month, 8);
      expect(lunar.birthday!.day, 15);
      // 农历生日也能算出倒计时
      expect(harness.contactController.upcomingForId(lunar.id), isNotNull);
    });

    widgetTest('导入后首页/联系人都能看到', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpImport(tester, harness);

      await paste(tester, '姓名：张三\n生日：新历5月23日');
      await tapImportButton(tester);

      expect(harness.contactController.upcoming, hasLength(1));
      expect(harness.contactController.visibleContacts, hasLength(1));
      // 固定时钟是 2026-05-20，所以是 3 天后
      expect(
        harness.contactController
            .upcomingForId(harness.contactController.contacts.single.id)!
            .daysUntil,
        3,
      );
    });
  });

  group('编辑页的「文本填充」', () {
    widgetTest('对话框会展示格式说明和实时预览', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await tester.pumpWidget(harness.wrap(const Scaffold()));
      await tester.pumpAndSettle();

      // 直接打开对话框（通过编辑页的按钮在编辑页测试里覆盖）
      final Future<ContactTextFillResult?> future = showContactTextFillDialog(
        tester.element(find.byType(Scaffold)),
      );
      await tester.pumpAndSettle();

      expect(find.text('从文本自动填充'), findsOneWidget);
      expect(find.text('支持的格式'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('fillTextField')),
        '姓名：张三\n生日：新历5月20日',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('将填充：张三'), findsOneWidget);
      expect(find.text('5月20日'), findsOneWidget);

      await tester.tap(find.byKey(const Key('applyFillButton')));
      await tester.pumpAndSettle();

      final ContactTextFillResult? result = await future;
      expect(result, isNotNull);
      expect(result!.contact, isNotNull);
      expect(result.contact!.name, '张三');
    });

    widgetTest('没有姓名时填充按钮不可用', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await tester.pumpWidget(harness.wrap(const Scaffold()));
      await tester.pumpAndSettle();

      final Future<ContactTextFillResult?> future = showContactTextFillDialog(
        tester.element(find.byType(Scaffold)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('fillTextField')),
        '生日：5月20日',
      );
      await tester.pumpAndSettle();

      final FilledButton button = tester.widget<FilledButton>(
        find.byKey(const Key('applyFillButton')),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining('还没识别出'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(await future, isNull);
    });
  });
}
