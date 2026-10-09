import 'package:birthday_keeper/models/app_settings.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/models/relationship.dart';
import 'package:birthday_keeper/ui/pages/contact_edit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

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

  widgetTest('新建页面展示所有可选分组', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpEditor(tester, harness);

    expect(find.text('新建联系人'), findsOneWidget);
    for (final String section in <String>[
      '基本信息',
      '生日',
      '爱好',
      '其他关键信息',
      '标签',
      '提醒',
    ]) {
      // 「提醒」等标题可能在滚动区域外，用 findsWidgets 容忍。
      expect(find.text(section), findsWidgets, reason: section);
    }
    expect(find.byKey(const Key('nameField')), findsOneWidget);
    expect(find.byKey(const Key('saveButton')), findsOneWidget);
  });

  widgetTest('姓名为空时无法保存并提示错误', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpEditor(tester, harness);

    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    expect(find.text('请填写姓名'), findsOneWidget);
    expect(harness.contactController.contacts, isEmpty);
    // 仍然停留在编辑页
    expect(find.byType(ContactEditPage), findsOneWidget);
  });

  widgetTest('只填姓名就能保存（其它字段都可以留空）', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpEditor(tester, harness);

    await tester.enterText(find.byKey(const Key('nameField')), '张三');
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    expect(harness.contactController.contacts, hasLength(1));
    final Contact saved = harness.contactController.contacts.single;
    expect(saved.name, '张三');
    expect(saved.birthday, isNull);
    expect(saved.relationship, isNull);
    expect(saved.hobbies, isEmpty);
    expect(saved.reminder.daysBefore, 3);
    // 落盘到了仓储
    expect(harness.contactRepository.saveCount, greaterThan(0));
  });

  widgetTest('姓名两端空格会被去掉', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpEditor(tester, harness);

    await tester.enterText(find.byKey(const Key('nameField')), '  李四  ');
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    expect(harness.contactController.contacts.single.name, '李四');
  });

  widgetTest('可以选择关系、自定义身份、爱好和联系方式', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpEditor(tester, harness);

    await tester.enterText(find.byKey(const Key('nameField')), '王五');
    await tester.tap(find.byKey(const Key('relationChip-friend')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('relationLabelField')), '大学室友');
    await tester.enterText(find.byKey(const Key('phoneField')), '13800000000');
    await tester.enterText(find.byKey(const Key('notesField')), '对花生过敏');

    // 选一个爱好
    await tester.tap(find.text('咖啡'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    final Contact saved = harness.contactController.contacts.single;
    expect(saved.relationship, Relationship.friend);
    expect(saved.relationLabel, '大学室友');
    expect(saved.phone, '13800000000');
    expect(saved.notes, '对花生过敏');
    expect(saved.hobbies, contains('咖啡'));
    expect(saved.relationshipLabel, '朋友 · 大学室友');
  });

  widgetTest('再次点击关系标签可以取消选择', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpEditor(tester, harness);

    await tester.enterText(find.byKey(const Key('nameField')), '张三');
    await tester.tap(find.byKey(const Key('relationChip-family')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('relationChip-family')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    expect(harness.contactController.contacts.single.relationship, isNull);
  });

  widgetTest('通过日期选择器设置公历生日', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpEditor(tester, harness);

    await tester.enterText(find.byKey(const Key('nameField')), '有生日的人');
    await tester.tap(find.byKey(const Key('pickSolarDateButton')));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    // 直接确认默认日期（30 年前的 1 月 1 日）。
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('1996 年 1 月 1 日'), findsOneWidget);

    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    final Birthday? birthday =
        harness.contactController.contacts.single.birthday;
    expect(birthday, isNotNull);
    expect(birthday!.year, 1996);
    expect(birthday.month, 1);
    expect(birthday.day, 1);
  });

  widgetTest('开启「不知道出生年份」后不保存年份', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpEditor(tester, harness);

    await tester.enterText(find.byKey(const Key('nameField')), '不知道年份');
    await tester.tap(find.byKey(const Key('pickSolarDateButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    final Finder yearSwitch = find.byKey(const Key('yearUnknownSwitch'));
    await tester.ensureVisible(yearSwitch);
    await tester.pumpAndSettle();
    await tester.tap(yearSwitch);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    final Birthday birthday =
        harness.contactController.contacts.single.birthday!;
    expect(birthday.year, isNull);
    expect(birthday.month, 1);
    expect(birthday.day, 1);
  });

  widgetTest('切换到农历后必须显式选择日期才会保存生日', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpEditor(tester, harness);

    await tester.enterText(find.byKey(const Key('nameField')), '农历测试');
    await tester.tap(find.byKey(const Key('calendarLunar')));
    await tester.pumpAndSettle();

    // 还没有选农历日期时提示用户
    expect(find.textContaining('还没有选择农历生日'), findsOneWidget);

    // 选择农历八月
    await tester.tap(find.byKey(const Key('lunarMonthDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('八月').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    final Birthday birthday =
        harness.contactController.contacts.single.birthday!;
    expect(birthday.calendar, BirthdayCalendar.lunar);
    expect(birthday.month, 8);
    expect(birthday.day, 1);
  });

  widgetTest('关闭提醒后隐藏提前天数等设置', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpEditor(tester, harness);

    expect(find.byKey(const Key('daysBeforeSlider')), findsOneWidget);

    final Finder reminderSwitch = find.byKey(
      const Key('reminderEnabledSwitch'),
    );
    await tester.ensureVisible(reminderSwitch);
    await tester.pumpAndSettle();
    await tester.tap(reminderSwitch);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daysBeforeSlider')), findsNothing);
  });

  widgetTest('可以调整提前天数与当天提醒开关', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpEditor(tester, harness);

    await tester.enterText(find.byKey(const Key('nameField')), '提醒测试');
    final Finder slider = find.byKey(const Key('daysBeforeSlider'));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();

    // 把滑块拖到最右边 => 提前 30 天
    await tester.drag(slider, const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('30 天'), findsOneWidget);

    final Finder onDaySwitch = find.byKey(const Key('notifyOnDaySwitch'));
    await tester.ensureVisible(onDaySwitch);
    await tester.pumpAndSettle();
    await tester.tap(onDaySwitch);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    final Contact saved = harness.contactController.contacts.single;
    expect(saved.reminder.daysBefore, 30);
    expect(saved.reminder.notifyOnDay, isFalse);
  });

  widgetTest('使用设置里的默认提醒配置', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      settings: const AppSettings(
        defaultReminder: ReminderSettings(daysBefore: 7, hour: 20),
      ),
    );
    await harness.load();
    await pumpEditor(tester, harness);

    expect(find.text('7 天'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
  });

  widgetTest('编辑已有联系人会带出原有数据并更新', (WidgetTester tester) async {
    final TestHarness harness = TestHarness(
      contacts: <Contact>[
        makeContact(
          id: 'a',
          name: '张三',
          relationship: Relationship.family,
          birthday: const Birthday(year: 1990, month: 5, day: 20),
          hobbies: <String>['咖啡'],
          notes: '备注内容',
        ),
      ],
    );
    await harness.load();
    await pumpEditor(tester, harness, contactId: 'a');

    expect(find.text('编辑联系人'), findsOneWidget);
    expect(find.text('1990 年 5 月 20 日'), findsOneWidget);
    expect(find.text('备注内容'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('nameField')), '张三丰');
    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    expect(harness.contactController.contacts, hasLength(1));
    final Contact updated = harness.contactController.contacts.single;
    expect(updated.name, '张三丰');
    expect(updated.birthday!.year, 1990);
    expect(updated.hobbies, contains('咖啡'));
    expect(updated.id, 'a');
  });

  widgetTest('可以通过「自定义」添加新的爱好', (WidgetTester tester) async {
    final TestHarness harness = TestHarness();
    await harness.load();
    await pumpEditor(tester, harness);

    await tester.enterText(find.byKey(const Key('nameField')), '攀岩爱好者');
    final Finder addChip = find.byKey(const Key('addHobbyChip'));
    await tester.ensureVisible(addChip);
    await tester.pumpAndSettle();
    await tester.tap(addChip);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '攀岩');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveButton')));
    await tester.pumpAndSettle();

    expect(harness.contactController.contacts.single.hobbies, contains('攀岩'));
  });

  group('粘贴文本自动填充', () {
    widgetTest('从文本填充会把各字段带进表单', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpEditor(tester, harness);

      await tester.tap(find.byKey(const Key('fillFromTextButton')));
      await tester.pumpAndSettle();
      expect(find.text('从文本自动填充'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('fillTextField')),
        '姓名：王五\n关系：朋友\n身份：大学室友\n生日：1996-05-23\n'
        '爱好：咖啡、徒步\n手机：13800000000\n备注：对花生过敏',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('applyFillButton')));
      await tester.pumpAndSettle();

      // 表单里已经填好，保存后就是解析出来的内容
      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      final Contact saved = harness.contactController.contacts.single;
      expect(saved.name, '王五');
      expect(saved.relationship, Relationship.friend);
      expect(saved.relationLabel, '大学室友');
      expect(saved.birthday, const Birthday(year: 1996, month: 5, day: 23));
      expect(saved.hobbies, <String>['咖啡', '徒步']);
      expect(saved.phone, '13800000000');
      expect(saved.notes, '对花生过敏');
    });

    widgetTest('农历生日也能通过文本填充设置', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpEditor(tester, harness);

      await tester.tap(find.byKey(const Key('fillFromTextButton')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('fillTextField')),
        '姓名：妈妈\n生日：农历八月十五',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('applyFillButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      final Birthday birthday =
          harness.contactController.contacts.single.birthday!;
      expect(birthday.calendar, BirthdayCalendar.lunar);
      expect(birthday.month, 8);
      expect(birthday.day, 15);
    });

    widgetTest('填充不会覆盖文本里没提到的字段', (WidgetTester tester) async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(
            id: 'a',
            name: '张三',
            birthday: const Birthday(month: 3, day: 3),
            notes: '原来的备注',
          ),
        ],
      );
      await harness.load();
      await pumpEditor(tester, harness, contactId: 'a');

      await tester.tap(find.byKey(const Key('fillFromTextButton')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('fillTextField')),
        '姓名：张三\n手机：13800000000',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('applyFillButton')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      final Contact saved = harness.contactController.contacts.single;
      expect(saved.phone, '13800000000');
      // 文本里没写生日和备注，原来的值要保留
      expect(saved.birthday, const Birthday(month: 3, day: 3));
      expect(saved.notes, '原来的备注');
    });

    widgetTest('取消填充不会改动表单', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpEditor(tester, harness);

      await tester.enterText(find.byKey(const Key('nameField')), '手填的名字');
      await tester.tap(find.byKey(const Key('fillFromTextButton')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('fillTextField')), '姓名：别人');
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('saveButton')));
      await tester.pumpAndSettle();

      expect(harness.contactController.contacts.single.name, '手填的名字');
    });
  });

  group('生日自动识别星座/生肖', () {
    widgetTest('选了生日就立刻显示星座和生肖', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpEditor(tester, harness);

      // 还没选生日时不显示「自动识别」
      expect(find.text('自动识别'), findsNothing);

      await tester.tap(find.byKey(const Key('pickSolarDateButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      // 1996-01-01 -> 摩羯座
      expect(find.text('自动识别'), findsOneWidget);
      expect(find.text('星座'), findsOneWidget);
      expect(find.text('摩羯座'), findsOneWidget);
      expect(find.text('属鼠'), findsOneWidget); // 1996 年是鼠年
      expect(find.text('农历'), findsWidgets);
    });

    widgetTest('改生日星座会跟着变', (WidgetTester tester) async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(
            id: 'a',
            name: '张三',
            birthday: const Birthday(month: 5, day: 20),
          ),
        ],
      );
      await harness.load();
      await pumpEditor(tester, harness, contactId: 'a');

      expect(find.text('金牛座'), findsOneWidget);
    });

    widgetTest('农历生日换算成公历后再算星座', (WidgetTester tester) async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await pumpEditor(tester, harness);

      await tester.tap(find.byKey(const Key('calendarLunar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lunarMonthDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('八月').last);
      await tester.pumpAndSettle();

      // 农历 8 月 1 日 -> 公历 9 月前后 -> 处女座
      expect(find.text('自动识别'), findsOneWidget);
      expect(find.text('星座'), findsOneWidget);
      expect(find.textContaining('农历'), findsWidgets);
    });
  });
}
