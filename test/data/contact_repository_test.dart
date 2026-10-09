import 'dart:io';

import 'package:birthday_keeper/data/contact_repository.dart';
import 'package:birthday_keeper/data/json_contact_repository.dart';
import 'package:birthday_keeper/data/json_store.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/models/relationship.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

void main() {
  group('InMemoryContactRepository', () {
    test('保存后能读回', () async {
      final InMemoryContactRepository repository = InMemoryContactRepository();
      expect(await repository.load(), isEmpty);

      await repository.save(<Contact>[makeContact(id: 'a', name: '甲')]);
      final List<Contact> loaded = await repository.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.name, '甲');
      expect(repository.saveCount, 1);
    });

    test('返回的是副本，外部修改不影响内部', () async {
      final InMemoryContactRepository repository = InMemoryContactRepository(
        <Contact>[makeContact(id: 'a')],
      );
      final List<Contact> first = await repository.load();
      first.clear();
      expect(await repository.load(), hasLength(1));
    });
  });

  group('JsonContactRepository', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bk_contacts');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    JsonStore store([String name = 'contacts.json']) =>
        JsonStore(resolveFile: () async => File('${tempDir.path}/$name'));

    test('文件不存在时返回空列表', () async {
      expect(await JsonContactRepository(store: store()).load(), isEmpty);
    });

    test('保存后能完整读回', () async {
      final JsonContactRepository repository = JsonContactRepository(
        store: store(),
      );
      final Contact contact = makeContact(
        id: 'a1',
        name: '张三',
        relationship: Relationship.friend,
        relationLabel: '大学室友',
        birthday: const Birthday(year: 1995, month: 5, day: 20),
        hobbies: <String>['咖啡', '徒步'],
        tags: <String>['重要'],
        phone: '13800000000',
        notes: '备注',
        favorite: true,
      );
      await repository.save(<Contact>[contact]);

      final List<Contact> loaded = await repository.load();
      expect(loaded, hasLength(1));
      final Contact restored = loaded.single;
      expect(restored.id, contact.id);
      expect(restored.name, contact.name);
      expect(restored.relationship, Relationship.friend);
      expect(restored.relationLabel, '大学室友');
      expect(restored.birthday, contact.birthday);
      expect(restored.hobbies, contact.hobbies);
      expect(restored.tags, contact.tags);
      expect(restored.phone, '13800000000');
      expect(restored.notes, '备注');
      expect(restored.favorite, isTrue);
    });

    test('保存空列表后读回空列表', () async {
      final JsonContactRepository repository = JsonContactRepository(
        store: store(),
      );
      await repository.save(<Contact>[makeContact()]);
      await repository.save(<Contact>[]);
      expect(await repository.load(), isEmpty);
    });

    test('写入的内容带有 schemaVersion', () async {
      await JsonContactRepository(
        store: store(),
      ).save(<Contact>[makeContact()]);
      final Map<String, Object?> raw = (await store().read())!;
      expect(raw['schemaVersion'], JsonContactRepository.schemaVersion);
      expect(raw['contacts'], isA<List<Object?>>());
    });

    test('单条数据损坏时跳过它而不是全部失败', () async {
      await store().write(<String, Object?>{
        'schemaVersion': 1,
        'contacts': <Object?>[
          makeContact(id: 'ok1', name: '正常一').toJson(),
          <String, Object?>{'id': 'bad'}, // 缺少 name
          'not-a-map',
          makeContact(id: 'ok2', name: '正常二').toJson(),
        ],
      });

      final List<Contact> loaded = await JsonContactRepository(
        store: store(),
      ).load();
      expect(loaded.map((Contact c) => c.id), <String>['ok1', 'ok2']);
    });

    test('contacts 字段类型不对时返回空列表', () async {
      await store().write(<String, Object?>{
        'schemaVersion': 1,
        'contacts': '不是数组',
      });
      expect(await JsonContactRepository(store: store()).load(), isEmpty);
    });

    test('整个文件损坏时返回空列表且不抛异常', () async {
      await File('${tempDir.path}/contacts.json').writeAsString('{{{');
      expect(await JsonContactRepository(store: store()).load(), isEmpty);
    });
  });
}
