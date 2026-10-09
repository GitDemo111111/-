import 'package:birthday_keeper/core/contact_text_parser.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/ui/pages/contact_import_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

/// 「一次粘贴很多人」的回归测试。
///
/// 用户反馈过「粘贴了 11 位，导入后只剩 1 位」，所以这里把**各种可能的写法**
/// 都钉住：只要文本里确实是 11 个人，就必须解析出 11 条、导入 11 位。
void main() {
  const ContactTextParser parser = ContactTextParser();

  // 11 个人的数据
  const List<String> names = <String>[
    '张三',
    '李四',
    '王五',
    '赵六',
    '钱七',
    '孙八',
    '周九',
    '吴十',
    '郑一',
    '冯二',
    '陈三',
  ];
  const List<String> dates = <String>[
    '1月5日',
    '2月6日',
    '3月7日',
    '4月8日',
    '5月9日',
    '6月10日',
    '7月11日',
    '8月12日',
    '9月13日',
    '10月14日',
    '11月15日',
  ];

  String build(String Function(int i, String name, String date) line) {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < names.length; i++) {
      buffer.writeln(line(i, names[i], dates[i]));
    }
    return buffer.toString();
  }

  group('解析：一次 11 位', () {
    test('标准格式（姓名：/ 生日：）', () {
      final String text = build(
        (int i, String n, String d) => '姓名：$n\n生日：新历$d',
      );
      expect(parser.parseValid(text), hasLength(11));
    });

    test('姓名和生日用逗号', () {
      final String text = build((int i, String n, String d) => '$n,$d');
      final List<ParsedContact> all = parser.parseValid(text);
      expect(all, hasLength(11), reason: '每行「姓名,生日」应该算一位');
      expect(all.first.name, '张三');
      expect(all.first.birthday!.month, 1);
      expect(all.first.birthday!.day, 5);
      expect(all.last.name, '陈三');
    });

    test('姓名和生日用空格', () {
      final String text = build((int i, String n, String d) => '$n $d');
      expect(parser.parseValid(text), hasLength(11));
    });

    test('姓名和生日用中文冒号', () {
      final String text = build((int i, String n, String d) => '$n：$d');
      final List<ParsedContact> all = parser.parseValid(text);
      expect(all, hasLength(11), reason: '「张三：1月5日」也该算一位');
      expect(all.first.name, '张三');
    });

    test('姓名和生日分开两行', () {
      final String text = build((int i, String n, String d) => '$n\n$d');
      expect(parser.parseValid(text), hasLength(11));
    });

    test('一行「姓名 生日」外加手机号', () {
      final String text = build(
        (int i, String n, String d) => '$n $d 1380000000$i',
      );
      final List<ParsedContact> all = parser.parseValid(text);
      expect(all, hasLength(11));
      expect(all.first.name, '张三');
      expect(all.first.birthday!.month, 1);
      expect(all.first.phone, '13800000000');
    });

    test('空行分隔 + 标准格式', () {
      final String text = build(
        (int i, String n, String d) => '姓名：$n\n生日：新历$d\n',
      );
      expect(parser.parseValid(text), hasLength(11));
    });

    test('农历写法一次 11 位', () {
      final String text = build(
        (int i, String n, String d) => '姓名：$n\n生日：农历$d',
      );
      final List<ParsedContact> all = parser.parseValid(text);
      expect(all, hasLength(11));
      expect(all.first.birthday!.calendar, BirthdayCalendar.lunar);
    });
  });

  group('界面：一次导入 11 位', () {
    Future<void> pump(WidgetTester tester, TestHarness harness) async {
      await tester.pumpWidget(harness.wrap(const ContactImportPage()));
      await tester.pumpAndSettle();
    }

    widgetTest('点击导入按钮后 11 位都在', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pump(tester, harness);

      // 用「姓名,生日」这种最随手的写法
      final String text = build((int i, String n, String d) => '$n,$d');
      await tester.enterText(find.byKey(const Key('importTextField')), text);
      await tester.pumpAndSettle();

      // 预览里 11 张卡都在
      for (int i = 0; i < 11; i++) {
        expect(
          find.byKey(Key('importPreview-$i')),
          findsOneWidget,
          reason: '第 ${i + 1} 张预览卡没出现',
        );
      }
      expect(find.text('11 位可导入'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('doImportButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('doImportButton')));
      await tester.pumpAndSettle();

      expect(
        harness.contactController.contacts,
        hasLength(11),
        reason: '导入 11 位后必须真的有 11 位联系人',
      );
      expect(
        harness.contactController.contacts.map((Contact c) => c.name).toSet(),
        names.toSet(),
      );
      // 落盘校验
      expect((await harness.contactRepository.load()), hasLength(11));
    });

    widgetTest('标准格式一次导入 11 位', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pump(tester, harness);

      final String text = build(
        (int i, String n, String d) => '姓名：$n\n生日：新历$d\n',
      );
      await tester.enterText(find.byKey(const Key('importTextField')), text);
      await tester.pumpAndSettle();
      expect(find.text('11 位可导入'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('doImportButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('doImportButton')));
      await tester.pumpAndSettle();

      expect(harness.contactController.contacts, hasLength(11));
    });
  });
}
