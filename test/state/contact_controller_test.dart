import 'package:birthday_keeper/core/reminder_planner.dart';
import 'package:birthday_keeper/data/contact_repository.dart';
import 'package:birthday_keeper/data/settings_repository.dart';
import 'package:birthday_keeper/models/app_settings.dart';
import 'package:birthday_keeper/models/birthday.dart';
import 'package:birthday_keeper/models/contact.dart';
import 'package:birthday_keeper/models/relationship.dart';
import 'package:birthday_keeper/state/contact_controller.dart';
import 'package:birthday_keeper/state/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_harness.dart';

/// 读取时直接抛异常的仓储，用来验证错误处理。
class _FailingContactRepository implements ContactRepository {
  @override
  Future<List<Contact>> load() async => throw StateError('磁盘炸了');

  @override
  Future<void> save(List<Contact> contacts) async {}
}

void main() {
  group('加载', () {
    test('起始状态是加载中，加载完成后可以读取', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[makeContact(id: 'a', name: '张三')],
      );
      expect(harness.contactController.isLoading, isTrue);

      await harness.load();

      expect(harness.contactController.isLoading, isFalse);
      expect(harness.contactController.contacts, hasLength(1));
      expect(harness.contactController.isEmpty, isFalse);
      expect(harness.contactController.loadError, isNull);
    });

    test('没有数据时 isEmpty 为 true', () async {
      final TestHarness harness = TestHarness();
      await harness.load();
      expect(harness.contactController.isEmpty, isTrue);
    });

    test('仓储出错时记录错误但不崩溃', () async {
      final SettingsController settings = SettingsController(
        repository: InMemorySettingsRepository(),
      );
      await settings.load();
      final ContactController controller = ContactController(
        repository: _FailingContactRepository(),
        settings: settings,
        clock: () => kNow,
      );

      await controller.load();

      expect(controller.contacts, isEmpty);
      expect(controller.loadError, isNotNull);
      expect(controller.isLoading, isFalse);
    });
  });

  group('增删改', () {
    test('addContact 会去掉姓名两端空格并分配头像颜色', () async {
      final TestHarness harness = TestHarness();
      await harness.load();

      final Contact created = await harness.contactController.addContact(
        makeContact(id: 'new-1', name: '  张三  '),
      );

      expect(created.name, '张三');
      expect(created.colorSeed, isNot(0));
      expect(harness.contactController.contacts, hasLength(1));
      expect(harness.contactRepository.saveCount, 1);
    });

    test('已经指定颜色的联系人不会被改写', () async {
      final TestHarness harness = TestHarness();
      await harness.load();
      final Contact created = await harness.contactController.addContact(
        makeContact(id: 'x', colorSeed: 3),
      );
      expect(created.colorSeed, 3);
    });

    test('updateContact 会替换同 id 的联系人', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[makeContact(id: 'a', name: '张三')],
      );
      await harness.load();

      await harness.contactController.updateContact(
        makeContact(id: 'a', name: '张三丰', notes: '改过了'),
      );

      final Contact? updated = harness.contactController.contactById('a');
      expect(updated!.name, '张三丰');
      expect(updated.notes, '改过了');
      expect(harness.contactController.contacts, hasLength(1));
    });

    test('updateContact 对不存在的 id 相当于新增', () async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await harness.contactController.updateContact(
        makeContact(id: 'ghost', name: '幽灵'),
      );
      expect(harness.contactController.contacts, hasLength(1));
    });

    test('deleteContact 会移除联系人', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(id: 'a', name: '甲'),
          makeContact(id: 'b', name: '乙'),
        ],
      );
      await harness.load();

      await harness.contactController.deleteContact('a');

      expect(
        harness.contactController.contacts.map((Contact c) => c.id),
        <String>['b'],
      );
      expect(harness.contactController.contactById('a'), isNull);
    });

    test('toggleFavorite 切换星标', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[makeContact(id: 'a')],
      );
      await harness.load();

      await harness.contactController.toggleFavorite('a');
      expect(harness.contactController.contactById('a')!.favorite, isTrue);
      expect(harness.contactController.favorites, hasLength(1));

      await harness.contactController.toggleFavorite('a');
      expect(harness.contactController.contactById('a')!.favorite, isFalse);
    });

    test('toggleFavorite 对不存在的 id 静默忽略', () async {
      final TestHarness harness = TestHarness();
      await harness.load();
      await harness.contactController.toggleFavorite('nope');
      expect(harness.contactController.contacts, isEmpty);
    });

    test('newContactId 生成的 id 不重复', () async {
      final TestHarness harness = TestHarness();
      final Set<String> ids = <String>{
        for (int i = 0; i < 50; i++) harness.contactController.newContactId(),
      };
      expect(ids, hasLength(50));
    });

    test('replaceAll 整体替换', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[makeContact(id: 'old')],
      );
      await harness.load();

      await harness.contactController.replaceAll(<Contact>[
        makeContact(id: 'n1', name: '新一'),
        makeContact(id: 'n2', name: '新二'),
      ]);

      expect(
        harness.contactController.contacts.map((Contact c) => c.id),
        <String>['n1', 'n2'],
      );
    });

    test('mergeAll 同 id 覆盖、新 id 追加', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(id: 'a', name: '旧名字'),
          makeContact(id: 'b', name: '乙'),
        ],
      );
      await harness.load();

      await harness.contactController.mergeAll(<Contact>[
        makeContact(id: 'a', name: '新名字'),
        makeContact(id: 'c', name: '丙'),
      ]);

      expect(harness.contactController.contacts, hasLength(3));
      expect(harness.contactController.contactById('a')!.name, '新名字');
      expect(harness.contactController.contactById('b')!.name, '乙');
      expect(harness.contactController.contactById('c')!.name, '丙');
    });

    test('clearAll 清空并取消提醒', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(id: 'a', birthday: const Birthday(month: 8, day: 15)),
        ],
      );
      await harness.load();
      expect(harness.scheduler.applied, isNotEmpty);

      await harness.contactController.clearAll();

      expect(harness.contactController.contacts, isEmpty);
      expect(harness.scheduler.applied, isEmpty);
    });

    test('每次修改都会通知监听者', () async {
      final TestHarness harness = TestHarness();
      await harness.load();
      int notifications = 0;
      harness.contactController.addListener(() => notifications++);

      await harness.contactController.addContact(makeContact(id: 'a'));

      expect(notifications, greaterThan(0));
    });
  });

  group('提醒排程', () {
    test('添加带生日的联系人后排上提醒', () async {
      final TestHarness harness = TestHarness();
      await harness.load();

      await harness.contactController.addContact(
        makeContact(
          id: 'a',
          name: '张三',
          birthday: const Birthday(month: 8, day: 15),
        ),
      );

      expect(harness.scheduler.applyCount, greaterThan(0));
      expect(harness.scheduler.applied, hasLength(4));
      expect(
        harness.scheduler.applied.every(
          (PendingReminder r) => r.contactId == 'a',
        ),
        isTrue,
      );
      expect(harness.contactController.scheduledReminders, hasLength(4));
    });

    test('关闭通知总开关后取消所有提醒', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(id: 'a', birthday: const Birthday(month: 8, day: 15)),
        ],
      );
      await harness.load();
      expect(harness.scheduler.applied, isNotEmpty);

      await harness.settingsController.patch(notificationsEnabled: false);

      expect(harness.scheduler.applied, isEmpty);
      expect(harness.scheduler.cancelCount, greaterThan(0));
      expect(harness.contactController.scheduledReminders, isEmpty);
      expect(harness.contactController.notificationsAllowed, isFalse);
    });

    test('重新打开总开关会重新排程', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(id: 'a', birthday: const Birthday(month: 8, day: 15)),
        ],
      );
      await harness.load();
      await harness.settingsController.patch(notificationsEnabled: false);
      await harness.settingsController.patch(notificationsEnabled: true);

      expect(harness.scheduler.applied, isNotEmpty);
    });

    test('requestNotificationPermission 记录授权结果', () async {
      final TestHarness granted = TestHarness();
      await granted.load();
      expect(
        await granted.contactController.requestNotificationPermission(),
        isTrue,
      );
      expect(granted.contactController.notificationsAllowed, isTrue);

      final TestHarness denied = TestHarness(permissionGranted: false);
      await denied.load();
      expect(
        await denied.contactController.requestNotificationPermission(),
        isFalse,
      );
      expect(denied.contactController.notificationsAllowed, isFalse);
    });

    test('没有调度器时只做规划，不影响其他功能', () async {
      final SettingsController settings = SettingsController(
        repository: InMemorySettingsRepository(),
      );
      await settings.load();
      final ContactController controller = ContactController(
        repository: InMemoryContactRepository(<Contact>[
          makeContact(id: 'a', birthday: const Birthday(month: 8, day: 15)),
        ]),
        settings: settings,
        clock: () => kNow,
      );

      await controller.load();

      expect(controller.scheduledReminders, hasLength(4));
      expect(controller.contacts, hasLength(1));
    });
  });

  group('派生数据', () {
    test('upcoming 按临近程度排序，没有生日的联系人被排除', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(id: 'no-birthday', name: '无生日'),
          makeContact(
            id: 'far',
            name: '远',
            birthday: const Birthday(month: 12, day: 1),
          ),
          makeContact(
            id: 'near',
            name: '近',
            birthday: const Birthday(month: 5, day: 22),
          ),
          makeContact(
            id: 'today',
            name: '今天',
            birthday: const Birthday(month: 5, day: 20),
          ),
        ],
      );
      await harness.load();

      expect(
        harness.contactController.upcoming.map((e) => e.contact.id),
        <String>['today', 'near', 'far'],
      );
      expect(harness.contactController.todayBirthdays, hasLength(1));
      expect(harness.contactController.upcomingWithinWeek, hasLength(1));
      expect(harness.contactController.contactsWithBirthday, 3);
    });

    test('同一天生日按姓名排序', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(
            id: 'b',
            name: '乙',
            birthday: const Birthday(month: 6, day: 1),
          ),
          makeContact(
            id: 'a',
            name: '甲',
            birthday: const Birthday(month: 6, day: 1),
          ),
        ],
      );
      await harness.load();
      // 注意：这里用的是 Dart 的字符串比较（按 UTF-16 码点），不是拼音。
      // 「乙」(U+4E59) 的码点小于「甲」(U+7532)，所以乙排在前面。
      expect(
        harness.contactController.upcoming.map((e) => e.contact.name),
        <String>['乙', '甲'],
      );
    });

    test('upcomingForId 返回对应条目', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(
            id: 'a',
            birthday: const Birthday(month: 5, day: 20, year: 2000),
          ),
        ],
      );
      await harness.load();

      final upcoming = harness.contactController.upcomingForId('a');
      expect(upcoming, isNotNull);
      expect(upcoming!.daysUntil, 0);
      expect(upcoming.turningAge, 26);
      expect(upcoming.countdownLabel, '今天');
      expect(upcoming.isToday, isTrue);
      expect(harness.contactController.upcomingForId('nope'), isNull);
    });

    test('分组：今天 / 7 天内 / 30 天内 / 更远', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(id: 'today', birthday: const Birthday(month: 5, day: 20)),
          makeContact(id: 'week', birthday: const Birthday(month: 5, day: 25)),
          makeContact(id: 'month', birthday: const Birthday(month: 6, day: 10)),
          makeContact(id: 'later', birthday: const Birthday(month: 11, day: 1)),
        ],
      );
      await harness.load();

      final List<UpcomingGroup> groups =
          harness.contactController.upcomingGroups;
      expect(groups.map((UpcomingGroup g) => g.title), <String>[
        '今天生日',
        '7 天内',
        '30 天内',
        '更远',
      ]);
      expect(groups.first.items.single.contact.id, 'today');
      expect(groups.first.subtitle, isNotEmpty);
    });

    test('关闭分组后只返回一个「全部生日」组', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(id: 'a', birthday: const Birthday(month: 5, day: 20)),
          makeContact(id: 'b', birthday: const Birthday(month: 11, day: 1)),
        ],
        settings: const AppSettings(groupUpcoming: false),
      );
      await harness.load();

      final List<UpcomingGroup> groups =
          harness.contactController.upcomingGroups;
      expect(groups, hasLength(1));
      expect(groups.single.title, '全部生日');
      expect(groups.single.items, hasLength(2));
    });

    test('没有生日时返回空分组', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[makeContact(id: 'a')],
      );
      await harness.load();
      expect(harness.contactController.upcomingGroups, isEmpty);
    });

    test('关系与爱好统计', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(
            id: 'a',
            relationship: Relationship.friend,
            hobbies: <String>['咖啡', '徒步'],
          ),
          makeContact(
            id: 'b',
            relationship: Relationship.friend,
            hobbies: <String>['咖啡'],
          ),
          makeContact(id: 'c', relationship: Relationship.family),
        ],
      );
      await harness.load();

      final List<FilterOption> relations =
          harness.contactController.relationshipFacets;
      expect(relations.first.label, '朋友');
      expect(relations.first.count, 2);

      final List<FilterOption> hobbies = harness.contactController.hobbyFacets;
      expect(hobbies.first.label, '咖啡');
      expect(hobbies.first.count, 2);
      expect(harness.contactController.usedHobbies, <String>{'咖啡', '徒步'});
    });
  });

  group('筛选与排序', () {
    TestHarness buildHarness() => TestHarness(
      contacts: <Contact>[
        makeContact(
          id: 'zhang',
          name: '张三',
          relationship: Relationship.colleague,
          hobbies: <String>['咖啡'],
          notes: '花生过敏',
        ),
        makeContact(
          id: 'li',
          name: '李四',
          relationship: Relationship.friend,
          hobbies: <String>['徒步'],
          favorite: true,
          birthday: const Birthday(month: 6, day: 1),
          createdAt: DateTime(2026, 3, 1),
        ),
        makeContact(
          id: 'wang',
          name: '王五',
          relationship: Relationship.friend,
          birthday: const Birthday(month: 7, day: 1),
          createdAt: DateTime(2026, 4, 1),
        ),
      ],
    );

    test('按姓名搜索', () async {
      final TestHarness harness = buildHarness();
      await harness.load();

      harness.contactController.setQuery('李');
      expect(
        harness.contactController.visibleContacts.map((Contact c) => c.id),
        <String>['li'],
      );
      expect(harness.contactController.searchQuery, '李');
    });

    test('搜索会匹配关系、爱好和备注', () async {
      final TestHarness harness = buildHarness();
      await harness.load();

      harness.contactController.setQuery('咖啡');
      expect(harness.contactController.visibleContacts, hasLength(1));
      harness.contactController.setQuery('同事');
      expect(harness.contactController.visibleContacts.single.id, 'zhang');
      harness.contactController.setQuery('过敏');
      expect(harness.contactController.visibleContacts.single.id, 'zhang');
      harness.contactController.setQuery('不存在的人');
      expect(harness.contactController.visibleContacts, isEmpty);
    });

    test('搜索大小写不敏感', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[makeContact(id: 'a', name: 'Alice')],
      );
      await harness.load();
      harness.contactController.setQuery('alice');
      expect(harness.contactController.visibleContacts, hasLength(1));
    });

    test('按关系筛选', () async {
      final TestHarness harness = buildHarness();
      await harness.load();

      harness.contactController.setRelationshipFilter(RelationshipGroup.friend);
      expect(harness.contactController.visibleContacts, hasLength(2));

      harness.contactController.setRelationshipFilter(null);
      expect(harness.contactController.visibleContacts, hasLength(3));
    });

    test('按爱好筛选（多选取交集）', () async {
      final TestHarness harness = buildHarness();
      await harness.load();

      harness.contactController.toggleHobbyFilter('咖啡');
      expect(harness.contactController.visibleContacts.single.id, 'zhang');

      harness.contactController.toggleHobbyFilter('徒步');
      expect(harness.contactController.visibleContacts, isEmpty);

      harness.contactController.toggleHobbyFilter('咖啡');
      expect(harness.contactController.visibleContacts.single.id, 'li');
    });

    test('只看星标', () async {
      final TestHarness harness = buildHarness();
      await harness.load();

      harness.contactController.setFavoritesOnly(true);
      expect(harness.contactController.visibleContacts.single.id, 'li');
    });

    test('clearFilters 重置全部筛选条件', () async {
      final TestHarness harness = buildHarness();
      await harness.load();

      harness.contactController.setQuery('李');
      harness.contactController.setRelationshipFilter(RelationshipGroup.friend);
      harness.contactController.toggleHobbyFilter('徒步');
      harness.contactController.setFavoritesOnly(true);
      expect(harness.contactController.hasActiveFilters, isTrue);

      harness.contactController.clearFilters();

      expect(harness.contactController.hasActiveFilters, isFalse);
      expect(harness.contactController.searchQuery, isEmpty);
      expect(harness.contactController.relationshipFilter, isNull);
      expect(harness.contactController.hobbyFilters, isEmpty);
      expect(harness.contactController.favoritesOnly, isFalse);
      expect(harness.contactController.visibleContacts, hasLength(3));
    });

    test('默认按生日临近排序，没有生日的排在最后', () async {
      final TestHarness harness = buildHarness();
      await harness.load();
      expect(
        harness.contactController.visibleContacts.map((Contact c) => c.id),
        <String>['li', 'wang', 'zhang'],
      );
    });

    test('按姓名排序', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(id: 'z', name: 'Zoe'),
          makeContact(id: 'a', name: 'Alice'),
          makeContact(id: 'm', name: 'Mike'),
        ],
        settings: const AppSettings(sortMode: ContactSortMode.name),
      );
      await harness.load();
      expect(
        harness.contactController.visibleContacts.map((Contact c) => c.id),
        <String>['a', 'm', 'z'],
      );
    });

    test('按最近修改排序', () async {
      final TestHarness harness = TestHarness(
        contacts: <Contact>[
          makeContact(id: 'old', name: '旧', createdAt: DateTime(2026, 1, 1)),
          makeContact(id: 'new', name: '新', createdAt: DateTime(2026, 4, 1)),
        ],
        settings: const AppSettings(sortMode: ContactSortMode.recentlyUpdated),
      );
      await harness.load();
      expect(
        harness.contactController.visibleContacts.map((Contact c) => c.id),
        <String>['new', 'old'],
      );
    });

    test('切换排序方式会立即生效', () async {
      final TestHarness harness = buildHarness();
      await harness.load();
      await harness.settingsController.patch(
        transform: (AppSettings s) =>
            s.copyWith(sortMode: ContactSortMode.name),
      );
      // 按 UTF-16 码点排序：张(5F20) < 李(674E) < 王(738B)
      expect(
        harness.contactController.visibleContacts.map((Contact c) => c.name),
        <String>['张三', '李四', '王五'],
      );
    });
  });

  test('dispose 之后设置变化不再触发提醒同步', () async {
    final TestHarness harness = TestHarness();
    await harness.load();
    final int before = harness.scheduler.applyCount;

    harness.contactController.dispose();
    await harness.settingsController.patch(notificationsEnabled: false);

    expect(harness.scheduler.applyCount, before);
  });
}
