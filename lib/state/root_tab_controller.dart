import 'package:flutter/foundation.dart';

/// 底部导航当前选中的页面。
///
/// 单独抽出来是为了让别处也能主动切标签 —— 例如「保存联系人」之后
/// 自动回到「联系人」页。
class RootTabController extends ChangeNotifier {
  static const int upcomingTab = 0;
  static const int contactsTab = 1;
  static const int settingsTab = 2;

  int _index = upcomingTab;

  int get index => _index;

  void goTo(int index) {
    if (_index == index) return;
    _index = index;
    notifyListeners();
  }

  /// 切到「联系人」页。
  void goToContacts() => goTo(contactsTab);
}
