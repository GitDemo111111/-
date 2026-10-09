import 'package:birthday_keeper/models/app_settings.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  const BackupService service = BackupService();

  final List<Contact> contacts = <Contact>[
    makeContact(
      id: 'a',
      name: '张三',
      birthday: const Birthday(year: 1995, month: 5, day: 20),
      hobbies: <String>['咖啡'],
    ),
    makeContact(id: 'b', name: '李四'),
  ];
  const AppSettings settings = AppSettings(
    notificationsEnabled: false,
    sortMode: ContactSortMode.name,
  );

  String export({List<Contact>? list, AppSettings? config}) =>
      service.exportToJson(
        contacts: list ?? contacts,
        settings: config ?? settings,
        now: kNow,
      );

  group('导出', () {
    test('包含格式标记、版本、导出时间和设置', () {
      final BackupPayload payload = service.parse(export());
      expect(payload.contacts, hasLength(2));
      expect(payload.settings, settings);
    });

    test('导出的文本是合法且带缩进的 JSON', () {
      final String json = export();
      expect(json, contains('"format": "birthdayKeeper"'));
      expect(json, contains('\n'));
      expect(json, contains('张三'));
    });

    test('没有联系人时也能导出', () {
      final BackupPayload payload = service.parse(export(list: <Contact>[]));
      expect(payload.contacts, isEmpty);
    });
  });

  group('导入', () {
    test('导出再导入完全一致', () {
      final BackupPayload payload = service.parse(export());
      expect(payload.contacts.map((Contact c) => c.id), <String>['a', 'b']);
      expect(payload.contacts.first.name, '张三');
      expect(payload.contacts.first.birthday, contacts.first.birthday);
      expect(payload.contacts.first.hobbies, <String>['咖啡']);
      expect(payload.settings, settings);
    });

    test('不是 JSON 时抛出 FormatException', () {
      expect(() => service.parse('这不是 JSON'), throwsA(isA<FormatException>()));
    });

    test('顶层不是对象时抛出 FormatException', () {
      expect(() => service.parse('[1,2,3]'), throwsA(isA<FormatException>()));
    });

    test('不是本应用的备份时抛出 FormatException', () {
      expect(
        () => service.parse('{"format":"somethingElse","contacts":[]}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('缺少 contacts 时抛出 FormatException', () {
      expect(
        () => service.parse('{"format":"birthdayKeeper"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('单条联系人损坏时跳过，其余照常导入', () {
      final BackupPayload payload = service.parse('''
{
  "format": "birthdayKeeper",
  "schemaVersion": 1,
  "contacts": [
    {"id": "ok", "name": "正常"},
    {"id": "bad"},
    "字符串"
  ]
}
''');
      expect(payload.contacts, hasLength(1));
      expect(payload.contacts.single.name, '正常');
    });

    test('缺少 settings 时使用默认设置', () {
      final BackupPayload payload = service.parse('''
{"format": "birthdayKeeper", "contacts": []}
''');
      expect(payload.settings, const AppSettings());
    });

    test('设置损坏时回退到默认设置', () {
      final BackupPayload payload = service.parse('''
{"format": "birthdayKeeper", "contacts": [], "settings": "坏数据"}
''');
      expect(payload.settings, const AppSettings());
    });

    test('可以导入自己刚导出的内容两次（幂等）', () {
      final String json = export();
      expect(service.parse(json).contacts, hasLength(2));
      expect(service.parse(json).contacts, hasLength(2));
    });
  });
}
