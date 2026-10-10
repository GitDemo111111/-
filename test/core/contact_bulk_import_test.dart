import 'package:birthday_keeper/core/contact_text_parser.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/state/root_tab_controller.dart';
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

  /// 用户真实粘贴的数据（原样），用于回归。
  const String kUserRealData = '''
姓名: 秦文芳
生日: 1972-09-18

姓名: 陈光华
生日: 1969-09-25

姓名: 陈光兰
生日: 年份不详-10-29

姓名: 二姐
生日: 年份不详-农历02-20

姓名: 大姐
生日: 年份不详-农历03-17（新历04-28）

姓名: 陈光书
生日: 年份不详-农历04-03

姓名: 七靓鹅公
生日: 年份不详-农历12-22

姓名: 陈大荣
生日: 1949-06-29

姓名: 赵书研
生日: 年份不详-农历05-10

姓名: 胡连福
生日: 1949-04-09

姓名: 陈大容
生日: 1949-06-29''';
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
  group('用户真实数据的 11 位', () {
    test('解析出 11 条', () {
      final List<ParsedContact> all = parser.parse(kUserRealData);
      expect(
        all,
        hasLength(11),
        reason:
            '实际解析出 ${all.length} 条：${all.map((ParsedContact c) => c.name).toList()}',
      );
      expect(all.map((ParsedContact c) => c.name).toList(), <String>[
        '秦文芳',
        '陈光华',
        '陈光兰',
        '二姐',
        '大姐',
        '陈光书',
        '七靓鹅公',
        '陈大荣',
        '赵书研',
        '胡连福',
        '陈大容',
      ]);
    });

    test('新历日期按新历，写农历的按农历', () {
      final List<ParsedContact> all = parser.parseValid(kUserRealData);
      expect(all, hasLength(11));
      final Map<String, ParsedContact> byName = <String, ParsedContact>{
        for (final ParsedContact c in all) c.name: c,
      };
      // 1972-09-18 这种 ISO 写法是新历
      expect(
        byName['秦文芳']!.birthday,
        const Birthday(year: 1972, month: 9, day: 18),
      );
      expect(
        byName['陈光华']!.birthday,
        const Birthday(year: 1969, month: 9, day: 25),
      );
      expect(
        byName['胡连福']!.birthday,
        const Birthday(year: 1949, month: 4, day: 9),
      );
      // 「年份不详-10-29」：年份没有，也不该被当成农历
      expect(byName['陈光兰']!.birthday!.calendar, BirthdayCalendar.solar);
      expect(byName['陈光兰']!.birthday!.month, 10);
      expect(byName['陈光兰']!.birthday!.day, 29);
      expect(byName['陈光兰']!.birthday!.year, isNull);
      // 明确写农历的
      expect(byName['二姐']!.birthday!.calendar, BirthdayCalendar.lunar);
      expect(byName['二姐']!.birthday!.month, 2);
      expect(byName['二姐']!.birthday!.day, 20);
      // 农历 + 括号里备注新历：取农历那一半
      expect(byName['大姐']!.birthday!.calendar, BirthdayCalendar.lunar);
      expect(byName['大姐']!.birthday!.month, 3);
      expect(byName['大姐']!.birthday!.day, 17);
      expect(byName['七靓鹅公']!.birthday!.calendar, BirthdayCalendar.lunar);
      expect(byName['七靓鹅公']!.birthday!.month, 12);
      expect(byName['七靓鹅公']!.birthday!.day, 22);
    });

    widgetTest('点导入后 11 位全部进来，并且回到联系人页', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await tester.pumpWidget(harness.wrap(const ContactImportPage()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('importTextField')),
        kUserRealData,
      );
      await tester.pumpAndSettle();
      expect(find.text('11 位可导入'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('doImportButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('doImportButton')));
      await tester.pumpAndSettle();

      expect(harness.contactController.contacts, hasLength(11));
      // 导入后要切到「联系人」页
      expect(harness.rootTabController.index, RootTabController.contactsTab);
    });
  });
}
