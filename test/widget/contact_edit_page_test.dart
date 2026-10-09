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
}
