import '../models/contact.dart';

/// 联系人仓储。
///
/// 这里刻意不依赖 `dart:io`：Web 预览版也复用这套接口。
abstract class ContactRepository {
  Future<List<Contact>> load();

  Future<void> save(List<Contact> contacts);
}

/// 内存实现，用于测试与预览。
class InMemoryContactRepository implements ContactRepository {
  InMemoryContactRepository([Iterable<Contact> initial = const <Contact>[]])
    : _contacts = List<Contact>.of(initial);

  List<Contact> _contacts;

  /// 记录保存次数，便于测试断言「确实落盘了」。
  int saveCount = 0;

  @override
  Future<List<Contact>> load() async => List<Contact>.of(_contacts);

  @override
  Future<void> save(List<Contact> contacts) async {
    saveCount++;
    _contacts = List<Contact>.of(contacts);
  }
}
