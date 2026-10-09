import 'package:flutter/foundation.dart';

import '../data/settings_repository.dart';
import '../models/app_settings.dart';
import '../models/birthday.dart';

/// 全局设置的状态。
class SettingsController extends ChangeNotifier {
  SettingsController({required SettingsRepository repository})
    : _repository = repository;

  final SettingsRepository _repository;

  AppSettings _settings = const AppSettings();
  bool _loaded = false;

  AppSettings get settings => _settings;

  /// 是否已经完成首次读取。
  bool get isLoaded => _loaded;

  Future<void> load() async {
    _settings = await _repository.load();
    _loaded = true;
    notifyListeners();
  }

  /// 覆盖设置。
  Future<void> update(AppSettings next) async {
    if (next == _settings) return;
    _settings = next;
    notifyListeners();
    await _repository.save(next);
  }

  /// 局部更新。
  Future<void> patch({
    bool? notificationsEnabled,
    AppSettings Function(AppSettings current)? transform,
  }) {
    var next = transform?.call(_settings) ?? _settings;
    if (notificationsEnabled != null) {
      next = next.copyWith(notificationsEnabled: notificationsEnabled);
    }
    return update(next);
  }

  /// 是否在首页显示「使用提示」卡片。
  Future<void> setShowTipCard(bool value) =>
      update(_settings.copyWith(showTipCard: value));

  /// 不再提示某一条。
  Future<void> hideTip(String id) {
    if (_settings.hiddenTipIds.contains(id)) return Future<void>.value();
    return update(
      _settings.copyWith(hiddenTipIds: <String>[..._settings.hiddenTipIds, id]),
    );
  }

  /// 恢复所有被忽略的提示。
  Future<void> restoreHiddenTips() =>
      update(_settings.copyWith(hiddenTipIds: const <String>[]));

  /// 文本导入的默认历法。
  Future<void> setImportCalendar(BirthdayCalendar value) =>
      update(_settings.copyWith(importCalendar: value));
}
