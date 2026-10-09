import 'package:birthday_keeper/core/reminder_planner.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/models/relationship.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  const ReminderPlanner planner = ReminderPlanner();

  List<PendingReminder> planFor(
    List<Contact> contacts, {
    DateTime? now,
    ReminderPlanner custom = planner,
  }) => custom.plan(contacts: contacts, now: now ?? kNow);

  group('默认提前 3 天 + 当天', () {
    test('生日还有 3 天时，提前提醒立刻发出，当天提醒正常排程', () {
      final Contact contact = makeContact(
        birthday: const Birthday(month: 5, day: 23),
      );
      final List<PendingReminder> reminders = planFor(<Contact>[contact]);

      // 2 次生日 × (提前 + 当天)
      expect(reminders, hasLength(4));

      final PendingReminder advance = reminders.firstWhere(
        (PendingReminder r) =>
            r.kind == ReminderKind.advance && r.occurrenceDate.year == 2026,
      );
      // 5/20 09:00 已经过去（现在是 10:00），所以立刻提醒。
      expect(advance.scheduledAt, kNow.add(const Duration(minutes: 1)));

      final PendingReminder onDay = reminders.firstWhere(
        (PendingReminder r) =>
            r.kind == ReminderKind.onDay && r.occurrenceDate.year == 2026,
      );
      expect(onDay.scheduledAt, DateTime(2026, 5, 23, 9));
    });

    test('生日还远时，提前提醒排在准确的时间点', () {
      final Contact contact = makeContact(
        birthday: const Birthday(month: 8, day: 15),
      );
      final PendingReminder advance = planFor(<Contact>[contact]).firstWhere(
        (PendingReminder r) =>
            r.kind == ReminderKind.advance && r.occurrenceDate.year == 2026,
      );
      expect(advance.scheduledAt, DateTime(2026, 8, 12, 9));
    });

    test('结果按触发时间升序', () {
      final List<PendingReminder> reminders = planFor(<Contact>[
        makeContact(
          id: 'a',
          name: '甲',
          birthday: const Birthday(month: 8, day: 15),
        ),
        makeContact(
          id: 'b',
          name: '乙',
          birthday: const Birthday(month: 6, day: 1),
        ),
      ]);
      for (int i = 1; i < reminders.length; i++) {
        expect(
          reminders[i].scheduledAt.isBefore(reminders[i - 1].scheduledAt),
          isFalse,
        );
      }
    });

    test('会同时排上明年的提醒，长期不打开 App 也不会漏', () {
      final Contact contact = makeContact(
        birthday: const Birthday(month: 8, day: 15),
      );
      final Iterable<int> years = planFor(<Contact>[
        contact,
      ]).map((PendingReminder r) => r.occurrenceDate.year);
      expect(years, containsAll(<int>[2026, 2027]));
    });

    test('occurrencesAhead 可以限制只排一次', () {
      final Contact contact = makeContact(
        birthday: const Birthday(month: 8, day: 15),
      );
      final List<PendingReminder> reminders = planFor(<Contact>[
        contact,
      ], custom: const ReminderPlanner(occurrencesAhead: 1));
      expect(reminders, hasLength(2));
    });
  });

  group('开关与边界', () {
    test('关闭提醒的联系人不产生任何提醒', () {
      final Contact contact = makeContact(
        birthday: const Birthday(month: 8, day: 15),
        reminder: const ReminderSettings(enabled: false),
      );
      expect(planFor(<Contact>[contact]), isEmpty);
    });

    test('没有生日就不提醒', () {
      expect(planFor(<Contact>[makeContact()]), isEmpty);
    });

    test('提前 0 天且关闭当天提醒时不产生提醒', () {
      final Contact contact = makeContact(
        birthday: const Birthday(month: 8, day: 15),
        reminder: const ReminderSettings(daysBefore: 0, notifyOnDay: false),
      );
      expect(planFor(<Contact>[contact]), isEmpty);
    });

    test('只要当天提醒', () {
      final Contact contact = makeContact(
        birthday: const Birthday(month: 8, day: 15),
        reminder: const ReminderSettings(daysBefore: 0),
      );
      final List<PendingReminder> reminders = planFor(<Contact>[contact]);
      expect(reminders, hasLength(2));
      expect(
        reminders.every((PendingReminder r) => r.kind == ReminderKind.onDay),
        isTrue,
      );
    });

    test('今天生日：当天提醒的时间已过就不再补发，明年照常', () {
      final Contact contact = makeContact(
        birthday: const Birthday(month: 5, day: 20),
      );
      final List<PendingReminder> reminders = planFor(<Contact>[contact]);
      expect(
        reminders.where((PendingReminder r) => r.occurrenceDate.year == 2026),
        isEmpty,
      );
      expect(
        reminders.where((PendingReminder r) => r.occurrenceDate.year == 2027),
        hasLength(2),
      );
    });

    test('今天生日但提醒时间还没到，会正常排上', () {
      final Contact contact = makeContact(
        birthday: const Birthday(month: 5, day: 20),
        reminder: const ReminderSettings(hour: 20),
      );
      final List<PendingReminder> reminders = planFor(<Contact>[
        contact,
      ]).where((PendingReminder r) => r.occurrenceDate.year == 2026).toList();
      expect(reminders, hasLength(1));
      expect(reminders.single.scheduledAt, DateTime(2026, 5, 20, 20));
    });

    test('提前 30 天时时间点正确', () {
      final Contact contact = makeContact(
        birthday: const Birthday(month: 6, day: 20),
        reminder: const ReminderSettings(daysBefore: 30),
      );
      final PendingReminder advance = planFor(<Contact>[
        contact,
      ]).firstWhere((PendingReminder r) => r.kind == ReminderKind.advance);
      expect(advance.scheduledAt, DateTime(2026, 5, 21, 9));
    });

    test('跨年提前提醒会落到上一年 12 月', () {
      final Contact contact = makeContact(
        birthday: const Birthday(month: 1, day: 5),
        reminder: const ReminderSettings(daysBefore: 10),
      );
      final PendingReminder advance = planFor(<Contact>[
        contact,
      ]).firstWhere((PendingReminder r) => r.kind == ReminderKind.advance);
      // 2027-01-05 往前 10 天 = 2026-12-26。
      expect(advance.scheduledAt, DateTime(2026, 12, 26, 9));
    });
  });

  group('通知文案', () {
    test('提前提醒包含姓名、天数和将满年龄', () {
      final Contact contact = makeContact(
        name: '李四',
        birthday: const Birthday(year: 1996, month: 8, day: 15),
      );
      final PendingReminder advance = planFor(<Contact>[
        contact,
      ]).firstWhere((PendingReminder r) => r.kind == ReminderKind.advance);
      expect(advance.title, contains('李四'));
      expect(advance.title, contains('生日'));
      expect(advance.body, contains('还有 87 天'));
      expect(advance.body, contains('满 30 岁'));
      expect(advance.payload, contact.id);
    });

    test('不知道出生年份时不提年龄', () {
      final Contact contact = makeContact(
        name: '王五',
        birthday: const Birthday(month: 8, day: 15),
      );
      final PendingReminder advance = planFor(<Contact>[
        contact,
      ]).firstWhere((PendingReminder r) => r.kind == ReminderKind.advance);
      expect(advance.body, isNot(contains('满')));
    });

    test('当天提醒的文案', () {
      final Contact contact = makeContact(
        name: '赵六',
        birthday: const Birthday(year: 2000, month: 5, day: 20),
        reminder: const ReminderSettings(hour: 20),
      );
      final PendingReminder onDay = planFor(<Contact>[
        contact,
      ]).firstWhere((PendingReminder r) => r.kind == ReminderKind.onDay);
      expect(onDay.title, contains('今天是赵六的生日'));
      expect(onDay.body, contains('满 26 岁'));
    });

    test('关系信息不会影响提醒内容', () {
      final Contact contact = makeContact(
        name: '钱七',
        relationship: Relationship.family,
        birthday: const Birthday(month: 8, day: 15),
      );
      expect(planFor(<Contact>[contact]), isNotEmpty);
    });
  });

  group('通知 id', () {
    test('同一个输入永远得到同样的 id', () {
      expect(
        notificationIdFor('c1', ReminderKind.advance, 0),
        notificationIdFor('c1', ReminderKind.advance, 0),
      );
    });

    test('不同联系人 / 不同种类 / 不同轮次互不相同', () {
      final int base = notificationIdFor('c1', ReminderKind.advance, 0);
      expect(base, isNot(notificationIdFor('c1', ReminderKind.onDay, 0)));
      expect(base, isNot(notificationIdFor('c2', ReminderKind.advance, 0)));
      expect(base, isNot(notificationIdFor('c1', ReminderKind.advance, 1)));
    });

    test('id 始终是正的 32 位整数', () {
      for (int i = 0; i < 500; i++) {
        for (final ReminderKind kind in ReminderKind.values) {
          final int id = notificationIdFor('contact-$i', kind, i % 2);
          expect(id, greaterThanOrEqualTo(0));
          expect(id, lessThanOrEqualTo(0x7FFFFFFF));
        }
      }
    });

    test('批量生成时冲突率很低', () {
      final Set<int> ids = <int>{};
      for (int i = 0; i < 400; i++) {
        ids.add(notificationIdFor('contact-$i', ReminderKind.advance, 0));
      }
      expect(ids.length, 400);
    });
  });

  group('农历生日提醒', () {
    test('农历生日也能排出提醒', () {
      final Contact contact = makeContact(
        name: '孙八',
        birthday: const Birthday(
          year: 1992,
          month: 8,
          day: 15,
          calendar: BirthdayCalendar.lunar,
        ),
      );
      final List<PendingReminder> reminders = planFor(<Contact>[contact]);
      expect(reminders, isNotEmpty);
      expect(
        reminders.every((PendingReminder r) => r.occurrenceDate.year >= 2026),
        isTrue,
      );
    });
  });
}
