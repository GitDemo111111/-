import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/birthday_calculator.dart';
import '../core/date_x.dart';
import '../core/reminder_planner.dart';
import '../data/contact_repository.dart';
import '../models/app_settings.dart';
import '../models/birthday.dart';
import '../models/contact.dart';
import '../models/relationship.dart';
import '../services/reminder_scheduler.dart';
import 'settings_controller.dart';

/// 「即将到来」页面的分组。
@immutable
class UpcomingGroup {
  const UpcomingGroup({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<UpcomingBirthday> items;
}

/// 一个可用的筛选项（关系分组或爱好）。
@immutable
class FilterOption {
  const FilterOption({
    required this.label,
    required this.count,
    this.relationshipGroup,
  });

  final String label;
  final int count;

  /// 关系分组筛选项对应的分组（爱好筛选项为 null）。
  final RelationshipGroup? relationshipGroup;
}

/// 联系人与提醒的核心状态。
class ContactController extends ChangeNotifier {
  ContactController({
    required ContactRepository repository,
    required SettingsController settings,
    ReminderScheduler? scheduler,
    BirthdayCalculator calculator = const BirthdayCalculator(),
    ReminderPlanner planner = const ReminderPlanner(),
    DateTime Function()? clock,
    Uuid? uuid,
  }) : _repository = repository,
       _settings = settings,
       _scheduler = scheduler,
       _calculator = calculator,
       _planner = planner,
       _clock = clock ?? DateTime.now,
       _uuid = uuid ?? const Uuid() {
    _settings.addListener(_onSettingsChanged);
  }

  final ContactRepository _repository;
  final SettingsController _settings;
  final ReminderScheduler? _scheduler;
  final BirthdayCalculator _calculator;
  final ReminderPlanner _planner;
  final DateTime Function() _clock;
  final Uuid _uuid;

  List<Contact> _contacts = <Contact>[];
  bool _loading = true;
  String? _loadError;

  String _query = '';
  RelationshipGroup? _relationshipFilter;
  final Set<String> _hobbyFilters = <String>{};
  bool _favoritesOnly = false;

  bool _notificationsAllowed = false;
  List<PendingReminder> _scheduledReminders = <PendingReminder>[];

  List<UpcomingBirthday>? _upcomingCache;
  List<Contact>? _visibleCache;
  Map<String, int>? _daysUntilCache;

  // ---------------------------------------------------------------- 只读状态

  List<Contact> get contacts => List<Contact>.unmodifiable(_contacts);
  bool get isLoading => _loading;
  String? get loadError => _loadError;
  bool get isEmpty => !_loading && _contacts.isEmpty;

  BirthdayCalculator get calculator => _calculator;
  String get searchQuery => _query;
  RelationshipGroup? get relationshipFilter => _relationshipFilter;
  Set<String> get hobbyFilters => Set<String>.unmodifiable(_hobbyFilters);
  bool get favoritesOnly => _favoritesOnly;

  /// 通知权限是否已获得（或不需要）。
  bool get notificationsAllowed => _notificationsAllowed;

  /// 最近一次实际排程的提醒，便于界面展示「已设置 N 条提醒」。
  List<PendingReminder> get scheduledReminders =>
      List<PendingReminder>.unmodifiable(_scheduledReminders);

  AppSettings get settings => _settings.settings;

  bool get hasActiveFilters =>
      _query.trim().isNotEmpty ||
      _relationshipFilter != null ||
      _hobbyFilters.isNotEmpty ||
      _favoritesOnly;

  // ------------------------------------------------------------ 派生数据

  Contact? contactById(String id) {
    for (final Contact contact in _contacts) {
      if (contact.id == id) return contact;
    }
    return null;
  }

  /// 当前时间（可注入，方便测试得到稳定的结果）。
  DateTime get now => _clock();

  /// 生成一个新的联系人 id。
  String newContactId() => _uuid.v4();

  /// 新建联系人时的默认提醒设置。
  ReminderSettings get defaultReminder => _settings.settings.defaultReminder;

  /// 所有联系人的下一个生日，按临近程度排序。
  List<UpcomingBirthday> get upcoming {
    final List<UpcomingBirthday>? cached = _upcomingCache;
    if (cached != null) return cached;
    final DateTime now = _clock();
    final List<UpcomingBirthday> result = <UpcomingBirthday>[];
    for (final Contact contact in _contacts) {
      final Birthday? birthday = contact.birthday;
      if (birthday == null) continue;
      final BirthdayOccurrence? occurrence = _calculator.nextOccurrence(
        birthday,
        now,
      );
      if (occurrence == null) continue;
      result.add(
        UpcomingBirthday(
          contact: contact,
          occurrence: occurrence,
          daysUntil: daysBetween(now, occurrence.date),
          turningAge: _calculator.ageAt(birthday, occurrence),
        ),
      );
    }
    result.sort((UpcomingBirthday a, UpcomingBirthday b) {
      final int byDays = a.daysUntil.compareTo(b.daysUntil);
      if (byDays != 0) return byDays;
      return a.contact.name.compareTo(b.contact.name);
    });
    _upcomingCache = List<UpcomingBirthday>.unmodifiable(result);
    return _upcomingCache!;
  }

  /// 某个联系人即将到来的生日（复用 [upcoming] 的缓存）。
  UpcomingBirthday? upcomingForId(String id) {
    for (final UpcomingBirthday item in upcoming) {
      if (item.contact.id == id) return item;
    }
    return null;
  }

  /// 今天过生日的联系人。
  List<UpcomingBirthday> get todayBirthdays => upcoming
      .where((UpcomingBirthday e) => e.daysUntil == 0)
      .toList(growable: false);

  /// 7 天内（不含今天）过生日的联系人。
  List<UpcomingBirthday> get upcomingWithinWeek => upcoming
      .where((UpcomingBirthday e) => e.daysUntil > 0 && e.daysUntil <= 7)
      .toList(growable: false);

  /// 30 天内过生日的数量（含今天）。
  int get upcomingWithinMonthCount =>
      upcoming.where((UpcomingBirthday e) => e.daysUntil <= 30).length;

  /// 按时间远近分组的「即将到来」。
  List<UpcomingGroup> get upcomingGroups {
    final List<UpcomingBirthday> all = upcoming;
    if (all.isEmpty) return const <UpcomingGroup>[];
    if (!settings.groupUpcoming) {
      return <UpcomingGroup>[
        UpcomingGroup(
          title: '全部生日',
          subtitle: '共 ${all.length} 位，按临近排序',
          items: all,
        ),
      ];
    }
    final List<UpcomingBirthday> today = <UpcomingBirthday>[];
    final List<UpcomingBirthday> week = <UpcomingBirthday>[];
    final List<UpcomingBirthday> month = <UpcomingBirthday>[];
    final List<UpcomingBirthday> later = <UpcomingBirthday>[];
    for (final UpcomingBirthday item in all) {
      if (item.daysUntil == 0) {
        today.add(item);
      } else if (item.daysUntil <= 7) {
        week.add(item);
      } else if (item.daysUntil <= 30) {
        month.add(item);
      } else {
        later.add(item);
      }
    }
    return <UpcomingGroup>[
      if (today.isNotEmpty)
        UpcomingGroup(title: '今天生日', subtitle: '别忘了送祝福 🎉', items: today),
      if (week.isNotEmpty)
        UpcomingGroup(title: '7 天内', subtitle: '提前准备礼物', items: week),
      if (month.isNotEmpty)
        UpcomingGroup(title: '30 天内', subtitle: '可以开始挑礼物了', items: month),
      if (later.isNotEmpty)
        UpcomingGroup(title: '更远', subtitle: '先记着', items: later),
    ];
  }

  Map<String, int> get _daysUntilById {
    final Map<String, int>? cached = _daysUntilCache;
    if (cached != null) return cached;
    final Map<String, int> map = <String, int>{
      for (final UpcomingBirthday item in upcoming)
        item.contact.id: item.daysUntil,
    };
    _daysUntilCache = map;
    return map;
  }

  /// 当前筛选/搜索/排序之后的联系人列表。
  List<Contact> get visibleContacts {
    final List<Contact>? cached = _visibleCache;
    if (cached != null) return cached;
    final String query = _query.trim().toLowerCase();
    final List<Contact> list = _contacts.where((Contact contact) {
      if (_favoritesOnly && !contact.favorite) return false;
      // 按「分组」筛选：爸爸/妈妈/爷爷… 都算「家人」
      if (_relationshipFilter != null &&
          contact.relationship?.group != _relationshipFilter) {
        return false;
      }
      if (_hobbyFilters.isNotEmpty &&
          !_hobbyFilters.every(contact.hobbies.contains)) {
        return false;
      }
      if (query.isNotEmpty && !contact.searchText.contains(query)) return false;
      return true;
    }).toList();
    list.sort(_compareContacts);
    _visibleCache = List<Contact>.unmodifiable(list);
    return _visibleCache!;
  }

  int _compareContacts(Contact a, Contact b) {
    switch (settings.sortMode) {
      case ContactSortMode.name:
        return a.name.compareTo(b.name);
      case ContactSortMode.recentlyUpdated:
        return b.updatedAt.compareTo(a.updatedAt);
      case ContactSortMode.daysUntil:
        final int? daysA = _daysUntilById[a.id];
        final int? daysB = _daysUntilById[b.id];
        if (daysA != null && daysB != null) {
          final int byDays = daysA.compareTo(daysB);
          if (byDays != 0) return byDays;
          return a.name.compareTo(b.name);
        }
        // 没有生日的排在后面
        if (daysA != null) return -1;
        if (daysB != null) return 1;
        return a.name.compareTo(b.name);
    }
  }

  /// 收藏的联系人。
  List<Contact> get favorites =>
      _contacts.where((Contact c) => c.favorite).toList(growable: false);

  /// 所有出现过 + 预设的爱好，用于筛选与编辑页面。
  Set<String> get usedHobbies => <String>{
    for (final Contact contact in _contacts) ...contact.hobbies,
  };

  /// 可用的关系筛选项（按分组，只列出真正用到的）。
  List<FilterOption> get relationshipFacets {
    final Map<RelationshipGroup, int> counts = <RelationshipGroup, int>{};
    for (final Contact contact in _contacts) {
      final RelationshipGroup? group = contact.relationship?.group;
      if (group == null) continue;
      counts[group] = (counts[group] ?? 0) + 1;
    }
    final List<FilterOption> options = counts.entries
        .map(
          (MapEntry<RelationshipGroup, int> e) => FilterOption(
            label: e.key.label,
            count: e.value,
            relationshipGroup: e.key,
          ),
        )
        .toList();
    options.sort(
      (FilterOption a, FilterOption b) => b.count.compareTo(a.count),
    );
    return options;
  }

  /// 可用的爱好筛选项。
  List<FilterOption> get hobbyFacets {
    final Map<String, int> counts = <String, int>{};
    for (final Contact contact in _contacts) {
      for (final String hobby in contact.hobbies) {
        counts[hobby] = (counts[hobby] ?? 0) + 1;
      }
    }
    final List<FilterOption> options = counts.entries
        .map(
          (MapEntry<String, int> e) =>
              FilterOption(label: e.key, count: e.value),
        )
        .toList();
    options.sort(
      (FilterOption a, FilterOption b) => b.count.compareTo(a.count),
    );
    return options;
  }

  /// 首页统计信息。
  int get totalContacts => _contacts.length;
  int get contactsWithBirthday =>
      _contacts.where((Contact c) => c.hasBirthday).length;

  // ------------------------------------------------------------ 生命周期

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      _contacts = await _repository.load();
    } on Object catch (error) {
      _contacts = <Contact>[];
      _loadError = '读取本地数据失败：$error';
    }
    _loading = false;
    _invalidateCaches();
    notifyListeners();
    await syncReminders();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    // 设置（排序方式、通知总开关）变化会同时影响派生数据与提醒排程。
    _invalidateCaches();
    notifyListeners();
    unawaited(syncReminders());
  }

  void _invalidateCaches() {
    _upcomingCache = null;
    _visibleCache = null;
    _daysUntilCache = null;
  }

  // ------------------------------------------------------------ 增删改

  /// 找出与 [incoming] **信息完全一致**的已有联系人（同日同名同内容）。
  ///
  /// 导入时用它做自动合并：找到就不重复添加，直接沿用已有的那一条。
  Contact? findIdentical(Contact incoming) {
    for (final Contact existing in _contacts) {
      if (existing.hasSameContent(incoming)) return existing;
    }
    return null;
  }

  /// 是否存在「同名但信息不同」的联系人。
  bool hasSameNameDifferentContent(Contact incoming) {
    final String name = incoming.name.trim().toLowerCase();
    return _contacts.any(
      (Contact c) =>
          c.name.trim().toLowerCase() == name && !c.hasSameContent(incoming),
    );
  }

  Future<Contact> addContact(Contact contact) async {
    final Contact prepared = _prepare(contact);
    _contacts = <Contact>[..._contacts, prepared];
    await _persist();
    return prepared;
  }

  /// 批量新增（「从文本导入」用）。
  ///
  /// 关键点：只落盘一次、只重排一次提醒。
  /// 之前导入是循环调用 [addContact]，每加一条都要 cancelAll + 重新排好全部
  /// 提醒（11 个人 ≈ 500 次插件调用），既慢又脆弱 —— 中间任何一次调用抛错
  /// 整个导入就中断，用户只看到进来两三个。
  Future<List<Contact>> addContacts(List<Contact> contacts) async {
    if (contacts.isEmpty) return const <Contact>[];
    final List<Contact> prepared = contacts
        .map<Contact>(_prepare)
        .toList(growable: false);
    _contacts = <Contact>[..._contacts, ...prepared];
    await _persist();
    return prepared;
  }

  /// 更新联系人；如果 id 不存在就当作新增（upsert）。
  Future<Contact> updateContact(Contact contact) async {
    final Contact prepared = _prepare(contact);
    final bool exists = _contacts.any((Contact item) => item.id == prepared.id);
    _contacts = exists
        ? _contacts
              .map((Contact item) => item.id == prepared.id ? prepared : item)
              .toList()
        : <Contact>[..._contacts, prepared];
    await _persist();
    return prepared;
  }

  Future<void> deleteContact(String id) async {
    _contacts = _contacts.where((Contact item) => item.id != id).toList();
    await _persist();
  }

  Future<void> toggleFavorite(String id) async {
    final Contact? contact = contactById(id);
    if (contact == null) return;
    await updateContact(
      contact.copyWith(favorite: !contact.favorite, updatedAt: _clock()),
    );
  }

  /// 用导入的数据整体替换（保留设置）。
  Future<void> replaceAll(List<Contact> contacts) async {
    _contacts = contacts.map(_prepare).toList();
    await _persist();
  }

  /// 合并导入的数据：同 id 覆盖，否则追加。
  Future<void> mergeAll(List<Contact> contacts) async {
    final Map<String, Contact> byId = <String, Contact>{
      for (final Contact c in _contacts) c.id: c,
    };
    for (final Contact c in contacts) {
      byId[c.id] = _prepare(c);
    }
    _contacts = byId.values.toList();
    await _persist();
  }

  Future<void> clearAll() async {
    _contacts = <Contact>[];
    await _persist();
  }

  Contact _prepare(Contact contact) => contact.copyWith(
    name: contact.name.trim(),
    colorSeed: contact.colorSeed == 0
        ? _colorSeedFor(contact.id)
        : contact.colorSeed,
  );

  static int _colorSeedFor(String id) {
    int sum = 0;
    for (final int unit in id.codeUnits) {
      sum = (sum + unit) & 0x7FFFFFFF;
    }
    return sum;
  }

  Future<void> _persist() async {
    _invalidateCaches();
    notifyListeners();
    await _repository.save(_contacts);
    await syncReminders();
  }

  // ------------------------------------------------------------ 筛选

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    _visibleCache = null;
    notifyListeners();
  }

  void setRelationshipFilter(RelationshipGroup? value) {
    if (_relationshipFilter == value) return;
    _relationshipFilter = value;
    _visibleCache = null;
    notifyListeners();
  }

  void toggleHobbyFilter(String hobby) {
    if (!_hobbyFilters.remove(hobby)) _hobbyFilters.add(hobby);
    _visibleCache = null;
    notifyListeners();
  }

  void setFavoritesOnly(bool value) {
    if (_favoritesOnly == value) return;
    _favoritesOnly = value;
    _visibleCache = null;
    notifyListeners();
  }

  void clearFilters() {
    _query = '';
    _relationshipFilter = null;
    _hobbyFilters.clear();
    _favoritesOnly = false;
    _visibleCache = null;
    notifyListeners();
  }

  // ------------------------------------------------------------ 提醒

  /// 请求通知权限。
  Future<bool> requestNotificationPermission() async {
    final ReminderScheduler? scheduler = _scheduler;
    if (scheduler == null) {
      _notificationsAllowed = true;
      notifyListeners();
      return true;
    }
    final bool granted = await scheduler.requestPermission();
    _notificationsAllowed = granted;
    notifyListeners();
    if (granted) await syncReminders();
    return granted;
  }

  /// 根据当前联系人重新排程本地通知。
  Future<void> syncReminders() async {
    final ReminderScheduler? scheduler = _scheduler;
    if (!_settings.settings.notificationsEnabled) {
      await scheduler?.cancelAll();
      _scheduledReminders = <PendingReminder>[];
      _notificationsAllowed = false;
      notifyListeners();
      return;
    }
    final List<PendingReminder> reminders = _planner.plan(
      contacts: _contacts,
      now: _clock(),
    );
    if (scheduler != null) {
      try {
        await scheduler.apply(reminders);
      } catch (_) {
        // 通知排程失败不能连累数据（导入 / 保存必须成功）
      }
      _notificationsAllowed = true;
    }
    _scheduledReminders = reminders;
    notifyListeners();
  }
}
