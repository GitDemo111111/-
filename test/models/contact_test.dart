import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/models/relationship.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  group('ReminderSettings', () {
    test('默认就是提前 3 天 + 当天 09:00', () {
      const ReminderSettings settings = ReminderSettings();
      expect(settings.enabled, isTrue);
      expect(settings.daysBefore, 3);
      expect(settings.notifyOnDay, isTrue);
      expect(settings.hour, 9);
      expect(settings.minute, 0);
      expect(settings.timeLabel, '09:00');
    });

    test('summary 文案', () {
      expect(const ReminderSettings().summary, '提前3天 + 当天 09:00');
      expect(const ReminderSettings(daysBefore: 0).summary, '当天 09:00');
      expect(const ReminderSettings(notifyOnDay: false).summary, '提前3天 09:00');
      expect(
        const ReminderSettings(daysBefore: 0, notifyOnDay: false).summary,
        '不提醒',
      );
      expect(const ReminderSettings(enabled: false).summary, '已关闭提醒');
    });

    test('copyWith 会把数值夹到合法区间', () {
      const ReminderSettings settings = ReminderSettings();
      expect(settings.copyWith(daysBefore: 999).daysBefore, 60);
      expect(settings.copyWith(daysBefore: -5).daysBefore, 0);
      expect(settings.copyWith(hour: 99).hour, 23);
      expect(settings.copyWith(minute: -1).minute, 0);
    });

    test('JSON 往返一致', () {
      const ReminderSettings original = ReminderSettings(
        enabled: false,
        daysBefore: 7,
        notifyOnDay: false,
        hour: 20,
        minute: 30,
      );
      expect(ReminderSettings.fromJson(original.toJson()), original);
    });

    test('JSON 数据异常时回退到默认值', () {
      final ReminderSettings parsed = ReminderSettings.fromJson(
        <String, Object?>{'enabled': 'yes', 'daysBefore': 1000, 'hour': -3},
      );
      expect(parsed.enabled, isTrue);
      expect(parsed.daysBefore, 60);
      expect(parsed.hour, 0);
    });
  });

  group('Contact', () {
    test('initial 取姓名首字', () {
      expect(makeContact(name: '张三').initial, '张');
      expect(makeContact(name: '  Alice ').initial, 'A');
      expect(makeContact(name: '   ').initial, '?');
    });

    test('initial 正确处理 emoji（代理对）', () {
      expect(makeContact(name: '😀小明').initial, '😀');
    });

    test('relationshipLabel 的组合方式', () {
      expect(makeContact().relationshipLabel, isNull);
      expect(
        makeContact(relationship: Relationship.family).relationshipLabel,
        '家人',
      );
      expect(makeContact(relationLabel: '大学室友').relationshipLabel, '大学室友');
      expect(
        makeContact(
          relationship: Relationship.friend,
          relationLabel: '大学室友',
        ).relationshipLabel,
        '朋友 · 大学室友',
      );
      expect(
        makeContact(
          relationship: Relationship.family,
          relationLabel: '家人',
        ).relationshipLabel,
        '家人',
      );
      expect(
        makeContact(
          relationship: Relationship.friend,
          relationLabel: '  ',
        ).relationshipLabel,
        '朋友',
      );
    });

    test('searchText 覆盖姓名、关系、爱好、备注和联系方式', () {
      final Contact contact = makeContact(
        name: '张三',
        relationship: Relationship.colleague,
        hobbies: <String>['咖啡'],
        notes: '对花生过敏',
        phone: '13800000000',
        relationLabel: '产品经理',
      );
      final String text = contact.searchText;
      expect(text, contains('张三'));
      expect(text, contains('同事'));
      expect(text, contains('产品经理'));
      expect(text, contains('咖啡'));
      expect(text, contains('花生'));
      expect(text, contains('13800000000'));
      expect(text, equals(text.toLowerCase()));
    });

    test('JSON 往返一致（含所有可选字段）', () {
      final Contact original = makeContact(
        id: 'abc',
        name: '李四',
        relationship: Relationship.friend,
        relationLabel: '大学室友',
        birthday: const Birthday(
          year: 1993,
          month: 11,
          day: 3,
          calendar: BirthdayCalendar.lunar,
          isLeapMonth: true,
        ),
        hobbies: <String>['徒步', '摄影'],
        tags: <String>['重要'],
        phone: '13900000000',
        email: 'a@b.com',
        wechat: 'lisi_wx',
        notes: '备注',
        giftIdeas: '喜欢机械键盘',
        avatarEmoji: '🐱',
        colorSeed: 7,
        favorite: true,
        reminder: const ReminderSettings(daysBefore: 5, hour: 18),
      );
      final Contact restored = Contact.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.relationship, original.relationship);
      expect(restored.relationLabel, original.relationLabel);
      expect(restored.birthday, original.birthday);
      expect(restored.hobbies, original.hobbies);
      expect(restored.tags, original.tags);
      expect(restored.phone, original.phone);
      expect(restored.email, original.email);
      expect(restored.wechat, original.wechat);
      expect(restored.notes, original.notes);
      expect(restored.giftIdeas, original.giftIdeas);
      expect(restored.avatarEmoji, original.avatarEmoji);
      expect(restored.colorSeed, original.colorSeed);
      expect(restored.favorite, original.favorite);
      expect(restored.reminder, original.reminder);
      expect(restored.createdAt, original.createdAt);
    });

    test('toJson 会省略空白字段', () {
      final Map<String, Object?> json = makeContact(
        name: '张三',
        notes: '   ',
        phone: '',
      ).toJson();
      expect(json.containsKey('notes'), isFalse);
      expect(json.containsKey('phone'), isFalse);
      expect(json.containsKey('birthday'), isFalse);
      expect(json.containsKey('hobbies'), isFalse);
    });

    test('缺少 id/name 时抛 FormatException', () {
      expect(
        () => Contact.fromJson(<String, Object?>{'name': '张三'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Contact.fromJson(<String, Object?>{'id': 'a'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('脏数据不会导致崩溃', () {
      final Contact parsed = Contact.fromJson(<String, Object?>{
        'id': 'a',
        'name': '张三',
        'hobbies': <Object?>['跑步', 42, '', null],
        'tags': 'not-a-list',
        'colorSeed': 'x',
        'favorite': 'yes',
        'reminder': 'not-a-map',
        'createdAt': '不是日期',
      });
      expect(parsed.hobbies, <String>['跑步']);
      expect(parsed.tags, isEmpty);
      expect(parsed.colorSeed, 0);
      expect(parsed.favorite, isFalse);
      expect(parsed.reminder, const ReminderSettings());
    });

    test('文本字段类型不对时退化为未填写，而不是抛异常', () {
      // 本地文件被手工改坏时，一个字段类型错误不应该让整份数据读不出来。
      final Contact parsed = Contact.fromJson(<String, Object?>{
        'id': 'a',
        'name': '张三',
        'relationship': 1,
        'relationLabel': true,
        'phone': 13800000000,
        'email': <String>[],
        'wechat': <String, Object?>{},
        'notes': 3.14,
        'giftIdeas': 0,
        'avatarEmoji': 9,
        'address': false,
      });
      expect(parsed.relationship, isNull);
      expect(parsed.relationLabel, isNull);
      expect(parsed.phone, isNull);
      expect(parsed.email, isNull);
      expect(parsed.wechat, isNull);
      expect(parsed.notes, isNull);
      expect(parsed.giftIdeas, isNull);
      expect(parsed.avatarEmoji, isNull);
      expect(parsed.address, isNull);
      expect(parsed.name, '张三');
    });

    test('生日字段类型不对时视为没有生日', () {
      final Contact parsed = Contact.fromJson(<String, Object?>{
        'id': 'a',
        'name': '张三',
        'birthday': '1990-05-20',
      });
      expect(parsed.birthday, isNull);
      expect(parsed.hasBirthday, isFalse);
    });

    test('copyWith 不传的参数保持不变', () {
      final Contact original = makeContact(name: '张三', notes: '备注');
      final Contact updated = original.copyWith(name: '张三丰');
      expect(updated.name, '张三丰');
      expect(updated.notes, '备注');
      expect(updated.id, original.id);
    });

    test('copyWith 可以用 null 显式清空字段', () {
      final Contact original = makeContact(
        name: '张三',
        notes: '备注',
        birthday: const Birthday(month: 5, day: 20),
        relationship: Relationship.friend,
      );
      final Contact cleared = original.copyWith(
        notes: null,
        birthday: null,
        relationship: null,
      );
      expect(cleared.notes, isNull);
      expect(cleared.birthday, isNull);
      expect(cleared.relationship, isNull);
      expect(cleared.name, '张三');
    });

    test('相等性基于 id', () {
      final Contact a = makeContact(id: 'x', name: '甲');
      final Contact b = makeContact(id: 'x', name: '乙');
      final Contact c = makeContact(id: 'y', name: '甲');
      expect(a, b);
      expect(a, isNot(c));
      expect(a.hashCode, b.hashCode);
    });

    test('hasBirthday', () {
      expect(makeContact().hasBirthday, isFalse);
      expect(
        makeContact(birthday: const Birthday(month: 5, day: 20)).hasBirthday,
        isTrue,
      );
    });
  });
}
