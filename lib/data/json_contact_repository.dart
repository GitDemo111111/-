import '../models/contact.dart';
import 'contact_repository.dart';
import 'json_store.dart';

/// 以 `contacts.json` 为载体的实现（手机 / 桌面端）。
class JsonContactRepository implements ContactRepository {
  JsonContactRepository({required JsonStore store}) : _store = store;

  static const int schemaVersion = 1;
  static const String contactsKey = 'contacts';

  final JsonStore _store;

  @override
  Future<List<Contact>> load() async {
    final Map<String, Object?>? data = await _store.read();
    if (data == null) return <Contact>[];
    final Object? raw = data[contactsKey];
    if (raw is! List) return <Contact>[];
    final List<Contact> result = <Contact>[];
    for (final Object? item in raw) {
      if (item is! Map) continue;
      try {
        result.add(Contact.fromJson(item.cast<String, Object?>()));
      } on Object {
        // 单条数据坏掉时跳过它，而不是让整个列表读不出来。
        // 这里刻意捕获所有异常：反序列化路径上任何意外都不应该导致
        // 用户「所有联系人都消失」。
        continue;
      }
    }
    return result;
  }

  @override
  Future<void> save(List<Contact> contacts) => _store.write(<String, Object?>{
    'schemaVersion': schemaVersion,
    contactsKey: contacts.map((Contact c) => c.toJson()).toList(),
  });
}
