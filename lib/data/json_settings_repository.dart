import '../models/app_settings.dart';
import 'json_store.dart';
import 'settings_repository.dart';

/// 以 `settings.json` 为载体的实现（手机 / 桌面端）。
class JsonSettingsRepository implements SettingsRepository {
  JsonSettingsRepository({required JsonStore store}) : _store = store;

  static const int schemaVersion = 1;
  static const String settingsKey = 'settings';

  final JsonStore _store;

  @override
  Future<AppSettings> load() async {
    final Map<String, Object?>? data = await _store.read();
    if (data == null) return const AppSettings();
    final Object? raw = data[settingsKey];
    if (raw is! Map) return const AppSettings();
    try {
      return AppSettings.fromJson(raw.cast<String, Object?>());
    } on Object {
      // 设置损坏时回退到默认值，保证 App 能启动。
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) => _store.write(<String, Object?>{
    'schemaVersion': schemaVersion,
    settingsKey: settings.toJson(),
  });
}
