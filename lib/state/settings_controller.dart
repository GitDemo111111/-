import 'package:flutter/foundation.dart';

import '../data/settings_repository.dart';
import '../models/app_settings.dart';

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
}
