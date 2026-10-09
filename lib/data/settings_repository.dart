import '../models/app_settings.dart';

/// 全局设置的仓储。
///
/// 同样不依赖 `dart:io`，方便 Web 预览版复用。
abstract class SettingsRepository {
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

/// 内存实现，用于测试。
class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([this._settings = const AppSettings()]);

  AppSettings _settings;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;
}
